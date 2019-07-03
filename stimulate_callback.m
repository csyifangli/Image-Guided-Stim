function stimulate_callback(hobject, eventdata)
    Resource = evalin('base','Resource');
    pos = getPosition(Resource.parameters.target_point);
    disp(pos)
    VsClose;
    ImageAcquisition('target_position',pos);

end