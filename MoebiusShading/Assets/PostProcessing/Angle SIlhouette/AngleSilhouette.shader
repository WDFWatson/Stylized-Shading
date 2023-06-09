Shader "PostProcessing/SurfaceAngleSilhouetting"
{
    HLSLINCLUDE
        #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
        TEXTURE2D_SAMPLER2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2);

        float4x4 UNITY_MATRIX_MVP;
        float4x4 _ViewProjectInverse;
        float _OutlineThickness;
        float _NormalSlope;
        float _DepthThreshold;
        float4 _OutlineColor;

        float SobelSampleDepth(Texture2D t, SamplerState s, float2 uv, float3 offset)
        {
            float pixelCenter = LinearEyeDepth(t.Sample(s, uv).r);
            float pixelLeft   = LinearEyeDepth(t.Sample(s, uv - offset.xz).r);
            float pixelRight  = LinearEyeDepth(t.Sample(s, uv + offset.xz).r);
            float pixelUp     = LinearEyeDepth(t.Sample(s, uv + offset.zy).r);
            float pixelDown   = LinearEyeDepth(t.Sample(s, uv - offset.zy).r);

            float sobelDepth = abs(pixelCenter-pixelLeft);
            sobelDepth += abs(pixelCenter-pixelRight);
            sobelDepth += abs(pixelCenter-pixelUp);
            sobelDepth += abs(pixelCenter-pixelDown);

            return  sobelDepth;
        }

        float4 SobelSample(Texture2D t, SamplerState s, float2 uv, float3 offset)
        {
            float4 pixelCenter = t.Sample(s, uv);
            float4 pixelLeft   = t.Sample(s, uv - offset.xz);
            float4 pixelRight  = t.Sample(s, uv + offset.xz);
            float4 pixelUp     = t.Sample(s, uv + offset.zy);
            float4 pixelDown   = t.Sample(s, uv - offset.zy);
            
            return abs(pixelLeft  - pixelCenter) +
                   abs(pixelRight - pixelCenter) +
                   abs(pixelUp    - pixelCenter) +
                   abs(pixelDown  - pixelCenter);
        }
    
        struct FragInput
        {
            float4 vertex : SV_Position;
            float2 texcoord : TEXCOORD0;
            float3 cameraDir : TEXCOORD1;
        };

        FragInput VertMain(AttributesDefault v)
        {
            FragInput o;
            
            o.vertex   = mul(UNITY_MATRIX_MVP, float4(v.vertex.xyz, 1.0));
            o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);
            #if UNITY_UV_STARTS_AT_TOP
            o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
            #endif


            // direction of camera in center of screen
            float4 cameraForwardDir = mul(_ViewProjectInverse, float4(0.0, 0.0, 0.5, 1.0));
            cameraForwardDir.xyz /= cameraForwardDir.w;
            cameraForwardDir.xyz -= _WorldSpaceCameraPos;

            //direction of camera at given pixel
            float4 cameraLocalDir = mul(_ViewProjectInverse, float4(o.texcoord.x * 2.0 - 1.0, o.texcoord.y * 2.0 - 1.0, 0.5, 1.0));
            cameraLocalDir.xyz /= cameraLocalDir.w;
            cameraLocalDir.xyz -= _WorldSpaceCameraPos;

            o.cameraDir = cameraLocalDir.xyz / length(cameraForwardDir.xyz);



            return o;
        }
    
        float4 FragMain(FragInput i) : SV_Target
        {
            float3 offset = float3((1.0 / _ScreenParams.x), (1.0 / _ScreenParams.y), 0.0);
            float3 sceneColor  = float3(0.2,0.2,0.8);
            float sceneDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord).r;
            float3 sceneNormal = SAMPLE_TEXTURE2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, i.texcoord).xyz * 2.0 - 1.0;

            float3 output = 0;
            float edge = 0;
            if(sceneDepth > 0)
            {
                
                sceneColor  = float3(1,1,1);
                float3 toCameraDir = normalize(-i.cameraDir);
                float silhouette = dot(toCameraDir, normalize(sceneNormal));
                float3 sobelNormalVec = SobelSample(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, i.texcoord.xy, offset);
                float sobelNormal = length(sobelNormalVec);
                if(silhouette <= _OutlineThickness && sobelNormal > _NormalSlope)
                {
                    edge = 1;
                }
                output.rgb = silhouette;
            }

            float sobelDepth = SobelSampleDepth(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord.xy, offset).r;
            sobelDepth = step(_DepthThreshold,sobelDepth);

            edge = saturate(max(sobelDepth,edge));

            float3 color = lerp(sceneColor, _OutlineColor, edge);
            return float4(color,1);
        }
    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertMain
                #pragma fragment FragMain
            ENDHLSL
        }
    }
}
