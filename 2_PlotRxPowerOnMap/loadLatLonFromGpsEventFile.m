function [lat, lon] = loadLatLonFromGpsEventFile(absDirToGpsEventJson)
% LOADLATLONFROMGPSEVENTFILE Load (latitude, longitude) from the .json GPS
% event file published by the Odin system.
%
% Yaguang Zhang, Purdue, 08/21/2021

jsonMsg = fileread(absDirToGpsEventJson);
data = jsondecode(jsonMsg);
lat = data.latitude.component;
lon = data.longitude.component;

end
% EOF