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
-- Copyright (C) 2015-2020, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        make.lua
--

-- imports
import("core.base.option")
import("lib.detect.find_file")

-- detect build-system and configuration file
function detect()
    return find_file("[mM]akefile", os.curdir())
end

-- do clean
function clean()
    os.vexec("make clean")
end

-- do build
function build()
    os.vexec("make -j" .. option.get("jobs"))
    cprint("${bright}build ok!")
end


