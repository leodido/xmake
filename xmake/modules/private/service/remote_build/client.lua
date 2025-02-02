--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        client.lua
--

-- imports
import("core.base.socket")
import("core.project.config", {alias = "project_config"})
import("devel.git")
import("lib.detect.find_tool")
import("private.service.config")
import("private.service.message")
import("private.service.client")
import("private.service.stream", {alias = "socket_stream"})

-- define module
local remote_build_client = remote_build_client or client()
local super = remote_build_client:class()

-- init client
function remote_build_client:init()
    super.init(self)

    -- init address
    local address = assert(config.get("remote_build.client.connect"), "config(remote_build.client.connect): not found!")
    super.address_set(self, address)

    -- get project directory
    local projectdir = os.projectdir()
    local projectfile = os.projectfile()
    if projectfile and os.isfile(projectfile) and projectdir then
        self._PROJECTDIR = projectdir
        self._WORKDIR = path.join(project_config.directory(), "remote_build")
    else
        raise("we need enter a project directory with xmake.lua first!")
    end

    -- check requires
    self:_check_requires()
end

-- get class
function remote_build_client:class()
    return remote_build_client
end

-- connect to the remote server
function remote_build_client:connect()
    if self:is_connected() then
        print("%s: has been connected!", self)
        return
    end
    local addr = self:addr()
    local port = self:port()
    local sock = socket.connect(addr, port)
    local session_id = self:session_id()
    local ok = false
    local errors
    print("%s: connect %s:%d ..", self, addr, port)
    if sock then
        local stream = socket_stream(sock)
        if stream:send_msg(message.new_connect(session_id)) and stream:flush() then
            local msg = stream:recv_msg()
            if msg then
                vprint(msg:body())
                if msg:success() then
                    ok = true
                else
                    errors = msg:errors()
                end
            end
        end
    end
    if ok then
        print("%s: connected!", self)
    else
        print("%s: connect %s:%d failed, %s", self, addr, port, errors or "unknown")
    end

    -- update status
    local status = self:status()
    status.addr = addr
    status.port = port
    status.connected = ok
    status.session_id = session_id
    self:status_save()

    -- sync files
    if ok then
        self:sync()
    end
end

-- disconnect server
function remote_build_client:disconnect()
    if not self:is_connected() then
        print("%s: has been disconnected!", self)
        return
    end
    local addr = self:addr()
    local port = self:port()
    local sock = socket.connect(addr, port)
    local session_id = self:session_id()
    local errors
    local ok = false
    print("%s: disconnect %s:%d ..", self, addr, port)
    if sock then
        local stream = socket_stream(sock)
        if stream:send_msg(message.new_disconnect(session_id)) and stream:flush() then
            local msg = stream:recv_msg()
            if msg then
                vprint(msg:body())
                if msg:success() then
                    ok = true
                else
                    errors = msg:errors()
                end
            end
        end
    end
    if ok then
        print("%s: disconnected!", self)
    else
        print("%s: disconnect %s:%d failed, %s", self, addr, port, errors or "unknown")
    end

    -- update status
    local status = self:status()
    status.connected = not ok
    self:status_save()
end

-- sync server files
function remote_build_client:sync()
    assert(self:is_connected(), "%s: has been not connected!", self)
    local addr = self:addr()
    local port = self:port()
    local sock = socket.connect(addr, port)
    local session_id = self:session_id()
    local errors
    local ok = false
    print("%s: sync files in %s:%d ..", self, addr, port)
    if sock then
        local stream = socket_stream(sock)
        if stream:send_msg(message.new_sync(session_id, true)) and stream:flush() then
            local msg = stream:recv_msg()
            if msg and msg:success() then
                vprint(msg:body())
                self:_do_syncfiles(msg:body().path, msg:body().branch)
                if stream:send_msg(message.new_sync(session_id, false)) and stream:flush() then
                    msg = stream:recv_msg()
                    if msg and msg:success() then
                        ok = true
                    elseif msg then
                        errors = msg:errors()
                    end
                end
            elseif msg then
                errors = msg:errors()
            end
        end
    end
    if ok then
        print("%s: sync files ok!", self)
    else
        print("%s: sync files failed in %s:%d, %s", self, addr, port, errors or "unknown")
    end
end

-- clean server files
function remote_build_client:clean()
    assert(self:is_connected(), "%s: has been not connected!", self)
    local addr = self:addr()
    local port = self:port()
    local sock = socket.connect(addr, port)
    local session_id = self:session_id()
    local errors
    local ok = false
    print("%s: clean files in %s:%d ..", self, addr, port)
    if sock then
        local stream = socket_stream(sock)
        if stream:send_msg(message.new_clean(session_id)) and stream:flush() then
            local msg = stream:recv_msg()
            if msg then
                vprint(msg:body())
                if msg:success() then
                    ok = true
                else
                    errors = msg:errors()
                end
            end
        end
    end
    if ok then
        print("%s: clean files ok!", self)
    else
        print("%s: clean files failed in %s:%d, %s", self, addr, port, errors or "unknown")
    end
end

-- run command
function remote_build_client:runcmd(program, argv)
    assert(self:is_connected(), "%s: has been not connected!", self)
    local addr = self:addr()
    local port = self:port()
    local sock = socket.connect(addr, port)
    local session_id = self:session_id()
    local errors
    local ok = false
    local command = os.args(table.join(program, argv))
    cprint("%s: run ${bright}%s${clear} in %s:%d ..", self, command, addr, port)
    if sock then
        local stream = socket_stream(sock)
        if stream:send_msg(message.new_runcmd(session_id, program, argv)) and stream:flush() then
            local msg = stream:recv_msg()
            if msg then
                vprint(msg:body())
                if msg:success() then
                    ok = true
                else
                    errors = msg:errors()
                end
            end
        end
    end
    if ok then
        print("%s: run command ok!", self)
    else
        print("%s: run command failed in %s:%d, %s", self, addr, port, errors or "unknown")
    end
end

-- is connected?
function remote_build_client:is_connected()
    return self:status().connected
end

-- get the status
function remote_build_client:status()
    local status = self._STATUS
    local statusfile = self:statusfile()
    if not status then
        if os.isfile(statusfile) then
            status = io.load(statusfile)
        end
        status = status or {}
        self._STATUS = status
    end
    return status
end

-- save status
function remote_build_client:status_save()
    io.save(self:statusfile(), self:status())
end

-- get the status file
function remote_build_client:statusfile()
    return path.join(self:workdir(), "status.txt")
end

-- get the project directory
function remote_build_client:projectdir()
    return self._PROJECTDIR
end

-- get working directory
function remote_build_client:workdir()
    return self._WORKDIR
end

-- get the session id, only for unique project
function remote_build_client:session_id()
    return self:status().session_id or hash.uuid():split("-", {plain = true})[1]:lower()
end

-- check requires
function remote_build_client:_check_requires()
    local git = find_tool("git")
    assert(git, "git not found!")
end

-- do syncfiles, e.g. git push user@addr:remote_path branch:remote_branch
function remote_build_client:_do_syncfiles(remote_path, remote_branch)
    local user = assert(config.get("remote_build.client.user"), "config(remote_build.client.user): not found!")
    local addr = self:addr()
    assert(remote_path, "git remote path not found!")
    assert(remote_branch, "git remote branch not found!")

    -- push to remote
    local remote_url = string.format("%s@%s:%s", user, addr, remote_path)
    git.push(remote_url, {remote_branch = remote_branch, verbose = true})
end

function remote_build_client:__tostring()
    return "<remote_build_client>"
end

-- is connected? we cannot depend on client:init when run action
function is_connected()
    local projectdir = os.projectdir()
    local projectfile = os.projectfile()
    if projectfile and os.isfile(projectfile) and projectdir then
        local workdir = path.join(project_config.directory(), "remote_build")
        local statusfile = path.join(workdir, "status.txt")
        if os.isfile(statusfile) then
            local status = io.load(statusfile)
            if status and status.connected then
                return true
            end
        end
    end
end

function main()
    local instance = remote_build_client()
    instance:init()
    return instance
end
