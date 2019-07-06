function [TW] = waveform_parameters_to_envelope(frequency, duty_cycle, prf, duration)

    max_cycles = 10000;
    total_cycles = duration*frequency;
    N = floor(total_cycles/max_cycles);
    waves_per_period = 1/prf*frequency;
    waves_on = ceil(duty_cycle * waves_per_period);
    waves_off = waves_per_period - waves_on;
    envPulseWidth = zeros([total_cycles,1]);

    on_count = 1;
    off_count = 0;
    for j = 1:total_cycles
        if on_count
            envPulseWidth(j) = 1;
            on_count = mod(on_count + 1,waves_on);
            if on_count == 0
                off_count = 1;
            end
        else
           off_count = mod(off_count + 1, waves_off);
           if off_count == 0
               on_count = 1;
           end
        end
    end
    
    if total_cycles < max_cycles
        TW.envNumCycles = total_cycles;
        TW.envFrequency = frequency/1e6*ones([total_cycles,1]);
        TW.envPulseWidth = envPulseWidth;
    else
        for i = 1:N   
            TW(i).envNumCycles =  max_cycles;% wavelengths
            TW(i).envFrequency = frequency/1e6*ones([max_cycles,1]);
            TW(i).envPulseWidth = envPulseWidth((i-1)*max_cycles+1 : i*max_cycles);
        end
            if total_cycles - N*max_cycles > 10
                remaining = envPulseWidth(i*max_cycles+1:end);
                TW(i+1).envNumCycles = length(remaining);
                TW(i+1).envFrequency = frequency/1e6*ones([length(remaining),1]);
                TW(i+1).envPulseWidth = remaining;
            end
    end
end