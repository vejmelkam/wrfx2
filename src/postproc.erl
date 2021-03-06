% Copyright (C) 2013-2015 Martin Vejmelka, UC Denver
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
% of the Software, and to permit persons to whom the Software is furnished to do
% so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
% INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR
% A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
% OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
% SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-module(postproc).
-author("Martin Vejmelka <vejmelkam@gmail.com>").
-export([render/6,render_domains/3,update_on_success/6]).
-include("wrfx2.hrl").


%% @doc Render a raster or contour from the instructions in <VarInfos>.
%% @doc Each instruction can be either {kml,V}, {png,V} or {contour_kml,V}, where
%% @doc V is the name of the variable.
-spec render(uuid(),string(),calendar:datetime(),calendar:datetime(),integer(),[{atom(),string()}]) -> ok.
render(Uuid,Workdir,SimFrom,SimTime,DomId,VarInfos) ->
  SimTimeS = timelib:to_esmf_str(SimTime),
  SimFromS = timelib:to_esmf_str(SimFrom),
  OutPath = filename:join([configsrv:get_conf(product_dir),Uuid,SimTimeS]),
  WrfOut = io_lib:format("~s/wrfout_d~2..0B_~s",[Workdir,DomId,SimFromS]),
  filelib:ensure_dir(filename:join(OutPath,"fakefile")),
  utils:log_info("postproc executing instructions ~p~n", [VarInfos]),
  lists:foreach(fun(VI) -> postprocess(Uuid,WrfOut,OutPath,SimTimeS,DomId,VI) end, VarInfos),
  ok.


-spec postprocess(uuid(),string(),string(),string(),pos_integer(),{atom(),string()}) -> pid().
postprocess(U,WrfOut,OutPath,SimTimeS,DomId,{kml,Var}) ->
  Cmd = lists:flatten(io_lib:format("deps/viswrf/raster2kml.py ~s ~s ~p ~s ~s", [WrfOut,Var,DomId,SimTimeS,OutPath])),
  spawn(fun () -> update_on_success(U,Var,SimTimeS,DomId,kml,Cmd) end);


postprocess(U,WrfOut,OutPath,SimTimeS,DomId,{png,Var}) ->
  Cmd = lists:flatten(io_lib:format("deps/viswrf/raster2png.py ~s ~s ~p ~s ~s", [WrfOut,Var,DomId,SimTimeS,OutPath])),
  spawn(fun() -> update_on_success(U,Var,SimTimeS,DomId,png,Cmd) end);


postprocess(U,WrfOut,OutPath,SimTimeS,DomId,{contour_kml,Var}) ->
  Cmd = lists:flatten(io_lib:format("deps/viswrf/contour2kml.py ~s ~s ~p ~s ~s", [WrfOut,Var,DomId,SimTimeS,OutPath])),
  spawn(fun() -> update_on_success(U,Var,SimTimeS,DomId,contour_kml,Cmd) end).


-spec render_domains(string(),pos_integer(),string()) -> pid().
render_domains(WpsWdir,NDoms,OutPath) ->
  Path = filename:join([configsrv:get_conf(product_dir),OutPath,"domains.kml"]),
  filelib:ensure_dir(Path),
  GeoEMs = lists:map(fun(I) -> filename:join(WpsWdir,io_lib:format("geo_em.d~2..0B.nc", [I])) end, lists:seq(1,NDoms)),
  Cmd = lists:flatten(["deps/viswrf/dom2kml.py domains ", Path, " ", string:join(GeoEMs, " ")]),
  spawn(fun() -> os:cmd(Cmd) end).


-spec update_on_success(uuid(),string(),string(),integer(),atom(),string()) -> ok.
update_on_success(U,Var,TS,DomId,Type,Cmd) -> 
  case os:cmd(Cmd ++ " &> /dev/null && echo $?") of
    "0\n" -> jobmaster:append_state(U,products,{Var,DomId,Type,lists:flatten(TS)}), ok;
    _Other -> ok
  end.

