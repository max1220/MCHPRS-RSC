-- plot methods:
--  plot:listPlayers()
--  plot:sendChatMessage(player_uuid, message)
--  plot:broadcastChatMessage(message)
--  plot:getDisableTicking()
--  plot:setDisableTicking(disable_ticking)
--  plot:setAlwaysRunning(always_running)
--  plot:getBlockID(x,y,z)
--  plot:setBlockID(x,y,z, block_id)

-- fields returned by plot:listPlayers():
--  username, uuid, x,y,z, yaw,pitch, first_x,first_y,first_z, second_x,second_y,second_z

-- globals:
--  MCHPRS_API_VERSION
--  MCHPRS_PLOT_X
--  MCHPRS_PLOT_Z
--  MCHPRS_PLOT_OWNER
--  PLOT

--function on_tick(plot) print("on_tick") end
function on_chat(plot, player_uuid, message_json) print("on_chat", player_uuid, message_json) end
function on_command(plot, player_uuid, command, args) print("on_command", player_uuid, command, args) end
function on_join(plot, player_uuid) print("on_join", player_uuid) end
function on_leave(plot, player_uuid) print("on_leave", player_uuid) end
function on_disconnect(plot, player_uuid) print("on_disconnect", player_uuid) end
function on_shutdown(plot) print("on_shutdown") end
function on_load(plot) print("on_load") end
