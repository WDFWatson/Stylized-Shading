using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[PostProcess(typeof(AngleSilhouetteRenderer),PostProcessEvent.AfterStack, "Custom/AngleSilhouette")]
public class AngleSilhouetteSettings : PostProcessEffectSettings
{
    [Range(0.0f, 1.0f)]
    public FloatParameter thickness = new FloatParameter { value = 0.2f };
    
    [Range(0.0f, 1.0f)]
    public FloatParameter normalSlope = new FloatParameter() { value = 0f };
    
    [Range(0.0f, 1.0f)]
    public FloatParameter depthThreshold = new FloatParameter() { value = 1f };

    public ColorParameter color = new ColorParameter { value = Color.black }; 
}
