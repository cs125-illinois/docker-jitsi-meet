local jid = require "util.jid";
local it = require "util.iterators";
local json = require "util.json";
local iterators = require "util.iterators";
local array = require"util.array";

local have_async = pcall(require, "util.async");
if not have_async then
  module:log("error", "requires a version of Prosody with util.async");
  return;
end

local async_handler_wrapper = module:require "util".async_handler_wrapper;

local tostring = tostring;
local neturl = require "net.url";
local parse = neturl.parseQuery;

local get_room_from_jid = module:require "util".get_room_from_jid;

-- required parameter for custom muc component prefix,
-- defaults to "muc"
local muc_domain_prefix = module:get_option_string("muc_mapper_domain_prefix", "muc");

-- Get full list from "all_rooms", then iterate to get each room details
function get_all(event)

  if (not event.request.url.query) then
    return { status_code = 400; };
  end

  local params = parse(event.request.url.query);
  local domain_name = params["domain"];

  local component = hosts[muc_domain_prefix.."."..domain_name]

  local allrooms=array() -- store the result of all_rooms()
  local state=array() -- store the final json

  if component then
    local muc = component.modules.muc
    if muc and rawget(muc,"all_rooms") then
      allrooms= muc.all_rooms();
    end
  end

  for room in allrooms do
    local room_state = get_room(room.jid)
    if room_state then
      state:push(room_state)
    end
  end

  return { status_code = 200; body = json.encode(state) };
end


function get_room (room_address)

  local room_name,domain_name=jid.split(room_address)
  if room_name:find("org.jitsi.jicofo.health") then
    return nil
  end

  local room = get_room_from_jid(room_address)
  local occupants = array()

  if not room or not room._occupants then
    return nil
  end

  for _, occupant in room:each_occupant() do
    -- filter focus as we keep it as hidden participant
    if string.sub(occupant.nick,-string.len("/focus"))~="/focus" then
      for _, pr in occupant:each_session() do
        local occupant = {id = tostring(occupant.nick)}

        local email = pr:get_child_text("email")
        if email then
          occupant["email"] = email
        end

        occupants:push(occupant)
      end
    end
  end

  return { domain=tostring(domain_name), name=tostring(room_name), occupants=occupants }
end


function module.load()
  module:depends("http");
  module:provides("http", {
      default_path = "/";
      route = {
        ["GET status"] = function (event) return async_handler_wrapper(event,get_all) end;
        ["GET sessions"] = function () return tostring(it.count(it.keys(prosody.full_sessions))); end;
      };
    });
end
