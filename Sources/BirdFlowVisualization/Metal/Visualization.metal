#include <metal_stdlib>
using namespace metal;

struct SurfaceVertex { float4 position; float4 normal; };
struct ColoredVertex {
    float4 position;
    float4 normal;
    float4 color;
    float4 parameters;
};
struct IsoVertex { float4 position; float4 normal; };
struct TracerState { float4 positionAndAge; float4 velocityAndSpeed; };
struct SliceProbeOutput { float4 worldAndScalar; float4 velocity; float4 vorticity; };
struct CameraUniforms { float4x4 viewProjection; float4 eyeAndWidth; };

struct CrowFeatherRootBindingGPU {
    uint4 sourceIndicesAndHash;
    uint4 ownershipAndIdentity;
    float4 localDirectionAndLength;
    float4 widthRachisAndPadding;
};

struct CrowFeatherRootStateGPU {
    float4 currentPositionAndLength;
    float4 previousPositionAndWidth;
    float4 currentDirectionAndRachis;
    float4 previousDirectionAndCamber;
    float4 currentNormalAndPadding;
    float4 previousNormalAndPadding;
    float4 previousMorphology;
    uint4 identity;
};

struct CrowFeatherDeformationUniforms {
    uint4 frameIndices;
    uint4 counts;
    float4 interpolation;
};

struct CrowStandingFeatherBindingGPU {
    uint4 identity;
    uint4 orderCountClassSide;
    float4 morphology;
};

struct CrowStandingFeatherUniforms {
    float4 phaseAndCount;
    float4 referenceBodyCenter;
};

struct CrowTakeoffFeatherBlendUniforms {
    float4 blendAndCount;
    float4 currentBodyTranslation;
    float4 previousBodyTranslation;
};

struct CrowFeatherTemplateVertexGPU { float4 parameters; };

struct CrowFeatherVertexGPU {
    float4 position;
    float4 normal;
    float4 color;
    float4 previousPosition;
    uint4 identity;
    float4 parameters;
};

struct CrowFeatherGeometryUniforms {
    uint4 counts;
    float4 renderOffsetAndDetailScale;
};

struct CrowBodyVaneMorphologyGPU {
    float4 rootAndRootWidth;
    float4 tipAndMaximumWidth;
    float4 normalAndCamber;
    float4 sweepAsymmetryAndRipple;
    float4 envelopeAndTaper;
    float4 color;
    float4 morphology;
    uint4 identity;
};

struct CrowBodyVaneRecordGPU {
    float4 currentRootAndRootWidth;
    float4 currentTipAndMaximumWidth;
    float4 previousRootAndCurrentCamber;
    float4 previousTipAndPreviousCamber;
    float4 currentNormalAndTransverseCamber;
    float4 previousNormalAndTransverseCamber;
    float4 sweepAsymmetryAndRipple;
    float4 envelopeAndTaper;
    float4 color;
    float4 morphology;
    uint4 identity;
};

struct CrowBodyVanePoseUniforms {
    float4 currentBodyCenterAndDeployment;
    float4 previousBodyCenterAndDeployment;
    float4 currentCranialRadiiAndBreathing;
    float4 previousCranialRadiiAndBreathing;
    float4 currentNeckTranslationAndYaw;
    float4 currentNeckPitchRollAndActive;
    float4 previousNeckTranslationAndYaw;
    float4 previousNeckPitchRollAndActive;
};

struct CrowBodyVaneNeckTransformGPU {
    float4 row0;
    float4 row1;
    float4 row2;
};

struct CrowBodyVaneGeometryUniforms {
    uint4 counts;
    float4 selection;
};

struct CrowBodyVaneSelectionUniforms {
    float4 selection;
    uint4 counts;
};

struct CrowCranialVisibilityUniforms {
    float4 leftPlane;
    float4 rightPlane;
    float4 bottomPlane;
    float4 topPlane;
    float4 nearPlane;
    float4 farPlane;
    float4 selection;
    uint4 counts;
    float4x4 previousViewProjection;
    float4 occlusionViewportBiasAndEnabled;
};

struct CrowBodyDetailSegmentGPU {
    float4 currentStartAndRadius;
    float4 currentEndAndRadius;
    float4 previousStartAndRadius;
    float4 previousEndAndRadius;
    float4 currentNormalAndKind;
    float4 previousNormalAndReserved;
};

struct CrowVentralRachisCurveRecordGPU {
    float4 rootAndPennaceousStart;
    float4 tipAndCamber;
    float4 normalAndTransverseCamber;
    float4 widthsEnvelopeAndAsymmetry;
    float4 edgeRippleAndMaterial;
    float4 lateralSweepAndReserved;
    uint4 identity;
};

struct CrowVentralRachisSegmentWorkGPU { uint4 indices; };

struct CrowVentralRachisGeometryUniforms {
    uint4 counts;
    float4 currentBodyCenter;
    float4 previousBodyCenter;
};

struct CrowVentralBarbSegmentWorkGPU { uint4 indices; };

struct CrowVentralBarbGeometryUniforms {
    uint4 counts;
    float4 currentBodyCenter;
    float4 previousBodyCenter;
};

struct CrowVentralBarbVisibilityUniforms {
    float4 leftPlane;
    float4 rightPlane;
    float4 bottomPlane;
    float4 topPlane;
    float4 nearPlane;
    float4 farPlane;
    float4 bodyCenterAndPadding;
    float4 occlusionBodyCenterAndPadding;
    float4 selection;
    uint4 counts;
    float4 barbuleSelection;
    float4x4 previousViewProjection;
    float4 occlusionViewportBiasAndEnabled;
};

kernel void copyCrowDeviceDepthToOcclusionLevel(
    depth2d<float,access::read> source [[texture(0)]],
    texture2d<float,access::write> destination [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    if(any(gid>=uint2(destination.get_width(),destination.get_height()))){return;}
    destination.write(source.read(gid),gid);
}

kernel void reduceCrowOcclusionDepthMax(
    texture2d<float,access::read> source [[texture(0)]],
    texture2d<float,access::write> destination [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]) {
    uint2 destinationSize=uint2(destination.get_width(),destination.get_height());
    if(any(gid>=destinationSize)){return;}
    uint2 sourceSize=uint2(source.get_width(),source.get_height());
    uint2 first=gid*2u;
    float maximum=0.0f;
    for(uint y=0u;y<2u;++y){
        for(uint x=0u;x<2u;++x){
            uint2 coordinate=min(first+uint2(x,y),sourceSize-1u);
            maximum=max(maximum,source.read(coordinate).x);
        }
    }
    destination.write(maximum,gid);
}

struct CrowSurfaceTemporalVertexGPU {
    float4 position;
    float4 previousPosition;
    float4 normal;
    float4 albedoAndMaterial;
    float4 parameters;
    uint4 identity;
};

struct CrowTemporalCameraUniforms {
    float4x4 viewProjection;
    float4x4 previousViewProjection;
    float4 eyeAndWidth;
    float4 viewportAndInverse;
    float4 plumageFilm;
    float4 plumageComplexIndices;
    float4 plumageMelanin;
    float4 plumageCortex;
    float4 plumageVisibilityShape;
    float4 plumageVisibilityLayout;
};

struct VisualizationUniforms {
    uint4 grid;
    uint4 flags;
    float4 originAndCellSize;
    float4 scalesAndRanges;
    float4 sliceCenterAndOpacity;
    float4 sliceUAndHalfWidth;
    float4 sliceVAndHalfHeight;
    float4 sliceNormalAndRange;
    float4 tracerAndIso;
    float4 displayOptions;
    float4 probeUVAndPadding;
    float4 bodyPosition;
    float4 orientation;
    float4 bodyRadiiAndTail;
    float4 wingGeometry0;
    float4 wingGeometry1;
    float4 leftRoot;
    float4 leftChord;
    float4 leftSpan;
    float4 leftNormal;
    float4 rightRoot;
    float4 rightChord;
    float4 rightSpan;
    float4 rightNormal;
};

struct RasterVertex {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float4 color;
    float2 uv;
};

struct CrowRasterVertex {
    float4 position [[position]];
    float4 previousClipPosition;
    float3 world;
    float3 normal;
    float4 albedoAndMaterial;
    float3 featherCoordinates;
    float3 resolvedCurveTangent;
    uint4 identity [[flat]];
};

struct CrowAOVOutput {
    half4 beauty [[color(0)]];
    half4 albedoAndMaterial [[color(1)]];
    half4 normal [[color(2)]];
    half2 motion [[color(3)]];
    float metricDepth [[color(4)]];
};

inline uint flatten(uint3 p, uint3 size) {
    return p.x + size.x * (p.y + size.y * p.z);
}

inline uint3 unflatten(uint index, uint3 size) {
    uint xy = size.x * size.y;
    uint z = index / xy;
    uint remainder = index - z * xy;
    uint y = remainder / size.x;
    return uint3(remainder - y * size.x, y, z);
}

inline float3 safeNormalizeCrow(float3 value,float3 fallback) {
    float magnitude=length(value);
    return magnitude>1.0e-12f?value/magnitude:fallback;
}

struct CrowSurfaceFrame {
    float3 root;
    float3 tangent;
    float3 bitangent;
    float3 normal;
};

inline float3 crowSurfacePoint(
    device const float4* points,
    uint vertexCount,
    uint firstFrame,
    uint secondFrame,
    float blend,
    uint vertexIndex) {
    return mix(
        points[firstFrame*vertexCount+vertexIndex].xyz,
        points[secondFrame*vertexCount+vertexIndex].xyz,
        blend
    );
}

inline CrowSurfaceFrame crowSurfaceFrame(
    device const float4* points,
    uint vertexCount,
    uint firstFrame,
    uint secondFrame,
    float blend,
    uint3 indices,
    uint chordIndex,
    uint featherClass,
    uint side) {
    CrowSurfaceFrame frame;
    frame.root=crowSurfacePoint(
        points,vertexCount,firstFrame,secondFrame,blend,indices.x
    );
    float3 partRoot=crowSurfacePoint(
        points,vertexCount,firstFrame,secondFrame,blend,indices.y
    );
    float3 partTip=crowSurfacePoint(
        points,vertexCount,firstFrame,secondFrame,blend,indices.z
    );
    float3 partAxis=safeNormalizeCrow(
        partTip-partRoot,
        featherClass==3u?float3(-1,0,0):float3(0,side==2u?-1.0f:1.0f,0)
    );
    if(featherClass==3u){
        frame.tangent=partAxis;
        frame.bitangent=safeNormalizeCrow(
            float3(0,1,0)-frame.tangent*frame.tangent.y,float3(0,1,0)
        );
        frame.normal=safeNormalizeCrow(
            -cross(frame.tangent,frame.bitangent),float3(0,0,1)
        );
    }else{
        frame.bitangent=partAxis;
        float3 partChord=crowSurfacePoint(
            points,vertexCount,firstFrame,secondFrame,blend,chordIndex
        )-partRoot;
        frame.tangent=safeNormalizeCrow(
            partChord-frame.bitangent*dot(partChord,frame.bitangent),float3(1,0,0)
        );
        float mirror=side==2u?-1.0f:1.0f;
        frame.normal=safeNormalizeCrow(
            mirror*cross(frame.tangent,frame.bitangent),float3(0,0,1)
        );
    }
    return frame;
}

inline float3 crowTransportDirection(
    float3 localDirection,
    CrowSurfaceFrame frame) {
    return safeNormalizeCrow(
        localDirection.x*frame.tangent
            +localDirection.y*frame.bitangent
            +localDirection.z*frame.normal,
        frame.tangent
    );
}

kernel void deformCrowFeatherRoots(
    device const float4* sourcePoints [[buffer(0)]],
    device const CrowFeatherRootBindingGPU* bindings [[buffer(1)]],
    device CrowFeatherRootStateGPU* output [[buffer(2)]],
    constant CrowFeatherDeformationUniforms& uniforms [[buffer(3)]],
    uint featherIndex [[thread_position_in_grid]]) {
    uint featherCount=uniforms.counts.y;
    if(featherIndex>=featherCount){return;}
    CrowFeatherRootBindingGPU binding=bindings[featherIndex];
    uint vertexCount=uniforms.counts.x;
    uint3 indices=binding.sourceIndicesAndHash.xyz;
    uint packedIdentity=binding.ownershipAndIdentity.y;
    uint featherClass=packedIdentity&255u;
    uint side=(packedIdentity>>8u)&255u;
    uint chordIndex=binding.ownershipAndIdentity.z;
    CrowSurfaceFrame current=crowSurfaceFrame(
        sourcePoints,vertexCount,
        uniforms.frameIndices.x,uniforms.frameIndices.y,
        uniforms.interpolation.x,indices,chordIndex,featherClass,side
    );
    CrowSurfaceFrame previous=crowSurfaceFrame(
        sourcePoints,vertexCount,
        uniforms.frameIndices.z,uniforms.frameIndices.w,
        uniforms.interpolation.y,indices,chordIndex,featherClass,side
    );
    float3 localDirection=binding.localDirectionAndLength.xyz;
    CrowFeatherRootStateGPU state;
    state.currentPositionAndLength=float4(
        current.root,binding.localDirectionAndLength.w
    );
    state.previousPositionAndWidth=float4(
        previous.root,binding.widthRachisAndPadding.x
    );
    state.currentDirectionAndRachis=float4(
        crowTransportDirection(localDirection,current),
        binding.widthRachisAndPadding.y
    );
    state.previousDirectionAndCamber=float4(
        crowTransportDirection(localDirection,previous),
        binding.widthRachisAndPadding.z
    );
    state.currentNormalAndPadding=float4(current.normal,0);
    state.previousNormalAndPadding=float4(previous.normal,0);
    state.previousMorphology=float4(
        binding.localDirectionAndLength.w,
        binding.widthRachisAndPadding.xyz
    );
    state.identity=uint4(
        featherIndex,
        binding.sourceIndicesAndHash.w,
        binding.ownershipAndIdentity.x,
        binding.ownershipAndIdentity.y
    );
    output[featherIndex]=state;
}

inline float crowClosedRectrixLengthScale(float radialFraction) {
    return (0.166f-0.006f*pow(clamp(radialFraction,0.0f,1.0f),1.35f))/0.166f;
}

struct CrowStandingRootPose {
    float3 root;
    float3 direction;
    float3 normal;
};

inline CrowStandingRootPose crowStandingRootPose(
    CrowStandingFeatherBindingGPU binding,
    float phase,
    float3 referenceBodyCenter) {
    float angle=2.0f*M_PI_F*phase;
    float3 motion=float3(
        0.0007f*sin(angle+0.35f),
        0.0018f*sin(angle),
        0.0011f*sin(2.0f*angle-0.45f)
    );
    float3 center=referenceBodyCenter+motion;
    uint count=max(binding.orderCountClassSide.y,1u);
    float fraction=float(binding.orderCountClassSide.x)/float(max(count-1u,1u));
    uint featherClass=binding.orderCountClassSide.z;
    uint sideCode=binding.orderCountClassSide.w;
    float side=sideCode==1u?1.0f:(sideCode==2u?-1.0f:0.0f);
    CrowStandingRootPose result;
    if(featherClass==1u){
        float featherLength=0.155f+0.050f*fraction;
        float stackSurfaceCoordinate=clamp((fraction-0.55f)/0.45f,0.0f,1.0f);
        float stackSurfaceEnvelope=sin(M_PI_F*stackSurfaceCoordinate);
        float stackSurfaceLift=0.0022f*stackSurfaceEnvelope;
        float primaryRootLateralOffset=0.042f-0.0024f
            *fraction*fraction*fraction+stackSurfaceLift;
        result.root=center+float3(
            0.040f-0.132f*fraction,
            side*primaryRootLateralOffset,
            0.032f-0.024f*fraction
        );
        float primaryTipLateralOffset=0.003f+0.001f*fraction
            -0.003f*fraction*fraction*fraction+stackSurfaceLift;
        float lateralDirection=side
            *(primaryTipLateralOffset-primaryRootLateralOffset)/featherLength;
        float tipHeight=-0.068f*fraction*fraction+0.062f*fraction-0.018f;
        float verticalDirection=(tipHeight-(result.root.z-center.z))/featherLength;
        result.direction=safeNormalizeCrow(
            float3(
                -sqrt(max(0.0f,1.0f-lateralDirection*lateralDirection
                    -verticalDirection*verticalDirection)),
                lateralDirection,
                verticalDirection
            ),
            float3(-1,0,0)
        );
        result.normal=safeNormalizeCrow(
            float3(
                0.030f,
                side,
                0.20f+0.08f*fraction
                    +0.18f*pow(sin(M_PI_F*fraction),2.0f)
            ),
            float3(0,side,0)
        );
    }else if(featherClass==2u){
        float featherLength=0.112f+0.030f*fraction;
        result.root=center+float3(
            0.082f-0.142f*fraction,
            side*0.047f,
            0.044f-0.024f*fraction
        );
        float posteriorTuck=pow(fraction,6.0f);
        float secondaryTipLateralOffset=0.027f+0.002f*fraction
            -0.018f*posteriorTuck;
        float lateralDirection=side*(secondaryTipLateralOffset-0.047f)/featherLength;
        float verticalDirection=(-0.012f*fraction-(result.root.z-center.z))/featherLength;
        result.direction=safeNormalizeCrow(
            float3(
                -sqrt(max(0.0f,1.0f-lateralDirection*lateralDirection
                    -verticalDirection*verticalDirection)),
                lateralDirection,
                verticalDirection
            ),
            float3(-1,0,0)
        );
        result.normal=safeNormalizeCrow(
            float3(0.025f,side,0.24f+0.06f*fraction),
            float3(0,side,0)
        );
    }else if(featherClass==3u){
        float centered=2.0f*fraction-1.0f;
        float radialFraction=abs(centered);
        float sideSign=centered==0.0f?0.0f:(centered>0.0f?1.0f:-1.0f);
        result.root=center+float3(
            -0.154f+0.003f*radialFraction,
            0.006f*centered,
            0.0065f-0.004f*radialFraction
        );
        float featherLength=0.166f*crowClosedRectrixLengthScale(radialFraction);
        float targetZ=-0.025f-0.002f*radialFraction;
        float verticalDirection=(targetZ-(result.root.z-center.z))/featherLength;
        result.direction=safeNormalizeCrow(
            float3(
                -sqrt(max(0.0f,1.0f-verticalDirection*verticalDirection)),
                0,
                verticalDirection
            ),
            float3(-1,0,0)
        );
        result.normal=safeNormalizeCrow(
            float3(
                0.04f,
                sideSign*(0.045f+0.110f*radialFraction),
                1
            ),
            float3(0,0,1)
        );
    }else{
        result.root=center+float3(-0.138f,0,0);
        result.direction=safeNormalizeCrow(
            float3(-1,0,-0.02f),float3(-1,0,0)
        );
        result.normal=float3(0,0,1);
    }
    return result;
}

kernel void poseStandingCrowFeatherRoots(
    device const CrowStandingFeatherBindingGPU* bindings [[buffer(0)]],
    device CrowFeatherRootStateGPU* output [[buffer(1)]],
    constant CrowStandingFeatherUniforms& uniforms [[buffer(2)]],
    uint featherIndex [[thread_position_in_grid]]) {
    uint featherCount=uint(uniforms.phaseAndCount.z);
    if(featherIndex>=featherCount){return;}
    CrowStandingFeatherBindingGPU binding=bindings[featherIndex];
    CrowStandingRootPose current=crowStandingRootPose(
        binding,uniforms.phaseAndCount.x,uniforms.referenceBodyCenter.xyz
    );
    CrowStandingRootPose previous=crowStandingRootPose(
        binding,uniforms.phaseAndCount.y,uniforms.referenceBodyCenter.xyz
    );
    CrowFeatherRootStateGPU state;
    uint featherClass=binding.orderCountClassSide.z;
    uint count=max(binding.orderCountClassSide.y,1u);
    float fraction=float(binding.orderCountClassSide.x)/float(max(count-1u,1u));
    float lengthScale=featherClass==3u
        ?crowClosedRectrixLengthScale(abs(2.0f*fraction-1.0f)):1.0f;
    float widthScale=1.0f;
    if(featherClass==1u){
        float exposureCoordinate=clamp((fraction-0.58f)/0.42f,0.0f,1.0f);
        float exposure=sin(M_PI_F*exposureCoordinate);
        float intermediateScale=1.0f+0.12f*exposure*exposure;
        float terminalCoordinate=clamp((fraction-0.88f)/0.12f,0.0f,1.0f);
        float terminalWeight=terminalCoordinate*terminalCoordinate
            *(3.0f-2.0f*terminalCoordinate);
        widthScale=intermediateScale*(1.0f-0.12f*terminalWeight);
    }else if(featherClass==2u){
        widthScale=1.0f-0.18f*pow(fraction,6.0f);
    }
    state.currentPositionAndLength=float4(
        current.root,binding.morphology.x*lengthScale
    );
    state.previousPositionAndWidth=float4(
        previous.root,binding.morphology.y*widthScale
    );
    state.currentDirectionAndRachis=float4(current.direction,binding.morphology.z);
    state.previousDirectionAndCamber=float4(previous.direction,binding.morphology.w);
    state.currentNormalAndPadding=float4(current.normal,0);
    state.previousNormalAndPadding=float4(previous.normal,0);
    state.previousMorphology=binding.morphology;
    state.previousMorphology.x*=lengthScale;
    state.previousMorphology.y*=widthScale;
    state.identity=binding.identity;
    output[featherIndex]=state;
}

// Mirrors CrowTakeoffSequence's identity and transition-progress contract so
// the live Metal root deformation follows the tested CPU schedule exactly.
inline float crowSmootherstep01(float value) {
    value=clamp(value,0.0f,1.0f);
    return value*value*value*(value*(value*6.0f-15.0f)+10.0f);
}

inline float crowLiveRectrixDeploymentWeight(float transitionProgress) {
    float normalized=clamp((transitionProgress-0.08f)/(0.62f-0.08f),0.0f,1.0f);
    return normalized*normalized*(3.0f-2.0f*normalized);
}

inline float crowRetainedRemexVisibility(
    uint packedIdentity,
    float transitionProgress) {
    uint featherClass=packedIdentity&255u;
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    float distanceFromTerminal=float(count-1u-min(order,count-1u));
    float endProgress=0.62f;
    if(featherClass==1u){
        endProgress=min(0.62f,0.20f+0.08f*distanceFromTerminal);
    }else if(featherClass==2u){
        endProgress=min(0.62f,0.30f+0.06f*distanceFromTerminal);
    }
    float normalized=clamp(
        (transitionProgress-0.08f)/(endProgress-0.08f),0.0f,1.0f
    );
    float deployment=normalized*normalized*(3.0f-2.0f*normalized);
    return 1.0f-deployment;
}

struct CrowTakeoffRectrixPose {
    float3 rootOffset;
    float3 direction;
    float3 normal;
};

inline float3 crowFlightRectrixCenterlinePoint(
    float rawFraction,
    float rawChordFraction) {
    float fraction=clamp(rawFraction,0.0f,1.0f);
    float chordFraction=clamp(rawChordFraction,0.0f,1.0f);
    float centered=2.0f*fraction-1.0f;
    float lateral=(fraction-0.5f)*0.145f;
    float central=1.0f-abs(centered);
    float3 root=float3(
        -0.125f,
        lateral*0.24f,
        0.005f+0.006f*central
    );
    float3 tip=float3(-0.125f,0,0.005f)
        +float3(-0.190f,0,-0.018f)*(0.96f+0.02f*central)
        +float3(
            -0.002f*central,
            lateral,
            (fraction-0.5f)*0.036f-0.003f*abs(centered)
        );
    return mix(root,tip,chordFraction);
}

inline float3 crowFlightRectrixCenterlineDerivative(
    float rawFraction,
    float rawChordFraction) {
    float fraction=clamp(rawFraction,0.0f,1.0f);
    float chordFraction=clamp(rawChordFraction,0.0f,1.0f);
    float centered=2.0f*fraction-1.0f;
    float side=centered>0.0f?1.0f:(centered<0.0f?-1.0f:0.0f);
    float centralDerivative=-2.0f*side;
    float radialDerivative=2.0f*side;
    float3 rootDerivative=float3(
        0.0f,
        0.145f*0.24f,
        0.006f*centralDerivative
    );
    float3 tipDerivative=float3(
        (-0.190f*0.02f-0.002f)*centralDerivative,
        0.145f,
        -0.018f*0.02f*centralDerivative+0.036f
            -0.003f*radialDerivative
    );
    return mix(rootDerivative,tipDerivative,chordFraction);
}

inline float3 crowFlightRectrixSurfaceNormal(float rawFraction) {
    float fraction=clamp(rawFraction,0.0f,1.0f);
    float3 spanTangent=crowFlightRectrixCenterlineDerivative(
        fraction,0.55f
    );
    float3 root=crowFlightRectrixCenterlinePoint(fraction,0.0f);
    float3 tip=crowFlightRectrixCenterlinePoint(fraction,1.0f);
    float3 normal=safeNormalizeCrow(
        cross(spanTangent,tip-root),float3(0,0,1)
    );
    return normal.z<0.0f?-normal:normal;
}

inline CrowTakeoffRectrixPose crowTakeoffRectrixPose(
    uint packedIdentity,
    float transitionProgress) {
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    float fraction=float(min(order,count-1u))/float(max(count-1u,1u));
    float centered=2.0f*fraction-1.0f;
    float radialFraction=abs(centered);
    float sideSign=centered==0.0f?0.0f:(centered>0.0f?1.0f:-1.0f);
    float3 closedRoot=float3(
        -0.154f+0.003f*radialFraction,
        0.006f*centered,
        0.0065f-0.004f*radialFraction
    );
    float closedLength=0.166f*crowClosedRectrixLengthScale(radialFraction);
    float verticalDirection=
        (-0.025f-0.002f*radialFraction-closedRoot.z)/closedLength;
    float3 closedDirection=safeNormalizeCrow(
        float3(
            -sqrt(max(0.0f,1.0f-verticalDirection*verticalDirection)),
            0,
            verticalDirection
        ),
        float3(-1,0,0)
    );
    float3 closedTip=closedRoot+closedLength*closedDirection;
    float3 closedNormal=safeNormalizeCrow(
        float3(0.04f,sideSign*(0.045f+0.110f*radialFraction),1),
        float3(0,0,1)
    );

    float3 flightRoot=crowFlightRectrixCenterlinePoint(fraction,0.0f);
    float3 flightTip=crowFlightRectrixCenterlinePoint(fraction,1.0f);
    float3 flightNormal=crowFlightRectrixSurfaceNormal(fraction);
    float deployment=crowLiveRectrixDeploymentWeight(transitionProgress);
    float3 rootOffset=mix(closedRoot,flightRoot,deployment);
    float3 tipOffset=mix(closedTip,flightTip,deployment);
    CrowTakeoffRectrixPose pose;
    pose.rootOffset=rootOffset;
    pose.direction=safeNormalizeCrow(tipOffset-rootOffset,closedDirection);
    pose.normal=safeNormalizeCrow(mix(closedNormal,flightNormal,deployment),closedNormal);
    return pose;
}

inline float crowTerminalPrimaryHandoffLateralOffsetMeters(
    uint packedIdentity,
    float transitionProgress) {
    uint featherClass=packedIdentity&255u;
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    if(featherClass!=1u||order+1u!=count){return 0.0f;}
    float rise=crowSmootherstep01((transitionProgress-0.004f)/(0.018f-0.004f));
    float release=crowSmootherstep01((transitionProgress-0.045f)/(0.080f-0.045f));
    return 0.004f*rise*(1.0f-release);
}

kernel void blendCrowTakeoffFeatherRoots(
    device const CrowFeatherRootStateGPU* standing [[buffer(0)]],
    device CrowFeatherRootStateGPU* output [[buffer(1)]],
    constant CrowTakeoffFeatherBlendUniforms& uniforms [[buffer(2)]],
    uint featherIndex [[thread_position_in_grid]]) {
    uint featherCount=uint(uniforms.blendAndCount.z);
    if(featherIndex>=featherCount){return;}
    CrowFeatherRootStateGPU grounded=standing[featherIndex];
    float currentBlend=uniforms.blendAndCount.x;
    float previousBlend=uniforms.blendAndCount.y;
    uint packedIdentity=grounded.identity.w;
    uint featherClass=packedIdentity&255u;
    if(featherClass==3u){
        CrowTakeoffRectrixPose closed=crowTakeoffRectrixPose(packedIdentity,0.0f);
        CrowTakeoffRectrixPose current=crowTakeoffRectrixPose(
            packedIdentity,currentBlend
        );
        CrowTakeoffRectrixPose previous=crowTakeoffRectrixPose(
            packedIdentity,previousBlend
        );
        uint order=(packedIdentity>>16u)&255u;
        uint count=max((packedIdentity>>24u)&255u,1u);
        float fraction=float(min(order,count-1u))/float(max(count-1u,1u));
        float closedLengthScale=crowClosedRectrixLengthScale(
            abs(2.0f*fraction-1.0f)
        );
        float currentLengthScale=mix(
            closedLengthScale,1.0f,crowLiveRectrixDeploymentWeight(currentBlend)
        );
        float previousLengthScale=mix(
            closedLengthScale,1.0f,crowLiveRectrixDeploymentWeight(previousBlend)
        );
        CrowFeatherRootStateGPU state;
        state.currentPositionAndLength=float4(
            grounded.currentPositionAndLength.xyz
                +uniforms.currentBodyTranslation.xyz
                +(current.rootOffset-closed.rootOffset),
            grounded.currentPositionAndLength.w
                *currentLengthScale/closedLengthScale
        );
        state.previousPositionAndWidth=float4(
            grounded.previousPositionAndWidth.xyz
                +uniforms.previousBodyTranslation.xyz
                +(previous.rootOffset-closed.rootOffset),
            grounded.previousPositionAndWidth.w
        );
        state.currentDirectionAndRachis=float4(
            current.direction,grounded.currentDirectionAndRachis.w
        );
        state.previousDirectionAndCamber=float4(
            previous.direction,grounded.previousDirectionAndCamber.w
        );
        state.currentNormalAndPadding=float4(current.normal,0);
        state.previousNormalAndPadding=float4(previous.normal,0);
        state.previousMorphology=grounded.previousMorphology;
        state.previousMorphology.x*=previousLengthScale/closedLengthScale;
        state.identity=grounded.identity;
        output[featherIndex]=state;
        return;
    }
    float currentFoldedVisibility=crowRetainedRemexVisibility(
        packedIdentity,currentBlend
    );
    float previousFoldedVisibility=crowRetainedRemexVisibility(
        packedIdentity,previousBlend
    );
    uint sideCode=(packedIdentity>>8u)&255u;
    float side=sideCode==1u?1.0f:(sideCode==2u?-1.0f:0.0f);
    float inverseLength=1.0f/max(grounded.currentPositionAndLength.w,1.0e-6f);
    float3 currentDirection=safeNormalizeCrow(
        grounded.currentDirectionAndRachis.xyz
            +float3(0,side*inverseLength
                *crowTerminalPrimaryHandoffLateralOffsetMeters(
                    packedIdentity,currentBlend),0),
        grounded.currentDirectionAndRachis.xyz
    );
    float3 previousDirection=safeNormalizeCrow(
        grounded.previousDirectionAndCamber.xyz
            +float3(0,side*inverseLength
                *crowTerminalPrimaryHandoffLateralOffsetMeters(
                    packedIdentity,previousBlend),0),
        grounded.previousDirectionAndCamber.xyz
    );
    CrowFeatherRootStateGPU state;
    state.currentPositionAndLength=float4(
        grounded.currentPositionAndLength.xyz+uniforms.currentBodyTranslation.xyz,
        grounded.currentPositionAndLength.w*currentFoldedVisibility
    );
    state.previousPositionAndWidth=float4(
        grounded.previousPositionAndWidth.xyz+uniforms.previousBodyTranslation.xyz,
        grounded.previousPositionAndWidth.w*previousFoldedVisibility
    );
    state.currentDirectionAndRachis=float4(
        currentDirection,
        grounded.currentDirectionAndRachis.w*currentFoldedVisibility
    );
    state.previousDirectionAndCamber=float4(
        previousDirection,
        grounded.previousDirectionAndCamber.w*previousFoldedVisibility
    );
    state.currentNormalAndPadding=grounded.currentNormalAndPadding;
    state.previousNormalAndPadding=grounded.previousNormalAndPadding;
    state.previousMorphology=grounded.previousMorphology*previousFoldedVisibility;
    state.identity=grounded.identity;
    output[featherIndex]=state;
}

inline float crowFeatherWidthEnvelope(float axial) {
    float body=0.32f+0.68f*pow(max(sin(M_PI_F*axial),0.0f),0.58f);
    return body*(1.0f-0.985f*pow(axial,3.2f));
}

inline float4 crowRectrixVaneProfile(uint packedIdentity) {
    if((packedIdentity&255u)!=3u){return float4(0);}
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    float fraction=float(min(order,count-1u))/float(max(count-1u,1u));
    float centered=2.0f*fraction-1.0f;
    float radialFraction=abs(centered);
    float side=centered>=0.0f?1.0f:-1.0f;
    return float4(
        radialFraction,
        -side,
        0.025f+0.045f*radialFraction,
        -0.050f+0.100f*radialFraction
    );
}

inline float crowRectrixTerminalShapeWeight(float axial) {
    float progress=clamp((axial-0.84f)/(1.0f-0.84f),0.0f,1.0f);
    return progress*progress*(3.0f-2.0f*progress);
}

inline float crowRectrixTerminalWidthEnvelope(float axial,float4 rectrix) {
    float inner=smoothstep(0.34f,0.46f,rectrix.x);
    float outer=smoothstep(0.84f,0.96f,rectrix.x);
    float handoffWeight=inner*(1.0f-outer);
    float terminalRatio=0.13f+0.03f*(1.0f-rectrix.x)
        +0.055f*handoffWeight;
    return max(
        crowFeatherWidthEnvelope(axial),
        terminalRatio*crowRectrixTerminalShapeWeight(axial)
    );
}

inline float crowRectrixTerminalRoundback(
    float axial,float signedWidth,float4 rectrix) {
    float boundedWidth=clamp(signedWidth,-1.0f,1.0f);
    return crowRectrixTerminalShapeWeight(axial)
        *(0.010f+0.004f*rectrix.x)*boundedWidth*boundedWidth;
}

inline float4 crowRemexVaneProfile(uint packedIdentity) {
    uint featherClass=packedIdentity&255u;
    if(featherClass!=1u&&featherClass!=2u){return float4(0);}
    uint sideCode=(packedIdentity>>8u)&255u;
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    float fraction=float(min(order,count-1u))/float(max(count-1u,1u));
    float dorsalSignedWidth=sideCode==2u?-1.0f:1.0f;
    float vaneAsymmetry=featherClass==1u
        ?0.075f+0.095f*fraction
        :0.040f+0.035f*fraction;
    float camberSkew=featherClass==1u
        ?0.015f+0.055f*fraction
        :-0.035f+0.025f*fraction;
    return float4(
        fraction,dorsalSignedWidth,vaneAsymmetry,camberSkew
    );
}

inline bool crowIsLiveCovert(uint featherClass) {
    return featherClass==12u||featherClass==13u
        ||featherClass==14u||featherClass==15u;
}

inline bool crowIsTrailingCovertRank(uint featherClass) {
    return featherClass==14u||featherClass==15u;
}

inline float crowTrailingCovertGlobalAxial(uint featherClass,float localAxial) {
    localAxial=clamp(localAxial,0.0f,1.0f);
    return featherClass==14u?0.72f*localAxial:
        (featherClass==15u?0.34f+0.66f*localAxial:localAxial);
}

inline float crowTrailingCovertSmoothstep(float value) {
    float t=clamp(value,0.0f,1.0f);
    return t*t*(3.0f-2.0f*t);
}

inline float crowTrailingCovertCoverage(uint featherClass,float localAxial) {
    float axial=crowTrailingCovertGlobalAxial(featherClass,localAxial);
    if(featherClass==14u){
        return 1.0f-crowTrailingCovertSmoothstep((axial-0.62f)/0.10f);
    }
    if(featherClass==15u){
        return crowTrailingCovertSmoothstep((axial-0.34f)/0.10f);
    }
    return 1.0f;
}

inline float crowTrailingCovertNormalOffset(uint featherClass,float localAxial) {
    if(featherClass==14u){return 0.00002f;}
    if(featherClass!=15u){return 0.0f;}
    float axial=crowTrailingCovertGlobalAxial(featherClass,localAxial);
    float rise=crowTrailingCovertSmoothstep((axial-0.34f)/0.10f);
    float fall=1.0f-crowTrailingCovertSmoothstep((axial-0.62f)/0.10f);
    return 0.00002f+0.00016f*rise*fall;
}

// span fraction, course fraction, mirrored exposed edge, vane asymmetry
inline float4 crowCovertVaneProfile0(uint packedIdentity) {
    uint featherClass=packedIdentity&255u;
    if(!crowIsLiveCovert(featherClass)){return float4(0);}
    uint sideCode=(packedIdentity>>8u)&255u;
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    uint courseCount=featherClass==12u?3u:1u;
    uint spanCount=max(count/courseCount,1u);
    uint safeOrder=min(order,count-1u);
    uint courseIndex=featherClass==12u
        ?min(safeOrder/spanCount,courseCount-1u):0u;
    uint spanOrder=safeOrder%spanCount;
    float spanFraction=float(spanOrder)/float(max(spanCount-1u,1u));
    float courseFraction=featherClass==12u
        ?float(courseIndex)/float(courseCount)
        :(featherClass==14u?0.42f:1.0f);
    float distalFraction=abs(2.0f*spanFraction-1.0f);
    float exposedSignedWidth=sideCode==2u?-1.0f:1.0f;
    float vaneAsymmetry=0.012f+0.010f*courseFraction
        +0.006f*distalFraction;
    return float4(
        spanFraction,courseFraction,exposedSignedWidth,vaneAsymmetry
    );
}

// camber skew, crown ratio, root-width ratio, edge amplitude
inline float4 crowCovertVaneProfile1(float4 covert) {
    float distalFraction=abs(2.0f*covert.x-1.0f);
    return float4(
        -0.035f+0.050f*covert.y+0.020f*(covert.x-0.5f),
        0.052f-0.015f*covert.y+0.004f*(1.0f-distalFraction),
        0.585f+0.030f*(1.0f-covert.y)+0.005f*(1.0f-distalFraction),
        0.007f+0.004f*covert.y+0.002f*distalFraction
    );
}

inline float crowCovertRootWidthRatio(uint packedIdentity,float4 covert) {
    uint featherClass=packedIdentity&255u;
    return crowIsTrailingCovertRank(featherClass)
        ?0.44f/0.78f:crowCovertVaneProfile1(covert).z;
}

inline float3 crowCovertEdgeMicrostructure(
    float axial,
    float signedWidth,
    float4 covert,
    float4 covertMorphology) {
    axial=clamp(axial,0.0f,1.0f);
    float sine=max(sin(M_PI_F*axial),0.0f);
    float cosine=cos(M_PI_F*axial);
    float sinePower=pow(sine,0.9f);
    float distalBias=0.42f+0.58f*axial;
    float envelope=sinePower*distalBias;
    float envelopeDerivative=0.9f*pow(max(sine,1.0e-6f),-0.1f)
        *M_PI_F*cosine*distalBias+0.58f*sinePower;
    float phase=0.45f+2.15f*covert.x+0.85f*covert.y
        +0.42f*signedWidth*covert.z;
    float firstFrequency=2.0f*M_PI_F*(3.75f+1.25f*covert.y);
    float secondFrequency=2.0f*M_PI_F*(8.25f+1.75f*covert.y);
    float firstAngle=firstFrequency*axial+phase;
    float secondAngle=secondFrequency*axial-0.68f*phase;
    float wave=0.70f*sin(firstAngle)+0.30f*sin(secondAngle);
    float waveAxialDerivative=0.70f*firstFrequency*cos(firstAngle)
        +0.30f*secondFrequency*cos(secondAngle);
    float phaseSignedWidthDerivative=0.42f*covert.z;
    float waveSignedWidthDerivative=0.70f*cos(firstAngle)
        *phaseSignedWidthDerivative
        -0.30f*0.68f*cos(secondAngle)*phaseSignedWidthDerivative;
    float amplitude=covertMorphology.w;
    return float3(
        1.0f+amplitude*envelope*wave,
        amplitude*(envelopeDerivative*wave+envelope*waveAxialDerivative),
        amplitude*envelope*waveSignedWidthDerivative
    );
}

inline float3 crowRemexEdgeMicrostructure(
    float axial,
    float signedWidth,
    uint packedIdentity,
    float4 remex) {
    axial=clamp(axial,0.0f,1.0f);
    uint featherClass=packedIdentity&255u;
    float sine=max(sin(M_PI_F*axial),0.0f);
    float cosine=cos(M_PI_F*axial);
    float sinePower=pow(sine,0.9f);
    float distalBias=0.30f+0.70f*axial;
    float envelope=sinePower*distalBias;
    float envelopeDerivative=0.9f*pow(max(sine,1.0e-6f),-0.1f)
        *M_PI_F*cosine*distalBias+0.70f*sinePower;
    float amplitude=featherClass==1u
        ?0.012f+0.008f*remex.x
        :0.010f+0.004f*remex.x;
    float phase=(featherClass==1u
        ?0.65f+2.70f*remex.x
        :1.10f+2.10f*remex.x)+0.38f*signedWidth*remex.y;
    float firstFrequency=2.0f*M_PI_F*(featherClass==1u?5.0f:4.0f);
    float secondFrequency=2.0f*M_PI_F*(featherClass==1u?11.0f:9.0f);
    float firstAngle=firstFrequency*axial+phase;
    float secondAngle=secondFrequency*axial-0.65f*phase;
    float wave=0.72f*sin(firstAngle)+0.28f*sin(secondAngle);
    float waveAxialDerivative=0.72f*firstFrequency*cos(firstAngle)
        +0.28f*secondFrequency*cos(secondAngle);
    float phaseSignedWidthDerivative=0.38f*remex.y;
    float waveSignedWidthDerivative=0.72f*cos(firstAngle)
        *phaseSignedWidthDerivative
        -0.28f*0.65f*cos(secondAngle)*phaseSignedWidthDerivative;
    return float3(
        1.0f+amplitude*envelope*wave,
        amplitude*(envelopeDerivative*wave+envelope*waveAxialDerivative),
        amplitude*envelope*waveSignedWidthDerivative
    );
}

inline float2 crowSmoothstepTerms(float value,float lower,float upper) {
    if(value<=lower){return float2(0.0f,0.0f);}
    if(value>=upper){return float2(1.0f,0.0f);}
    float normalized=(value-lower)/(upper-lower);
    return float2(
        normalized*normalized*(3.0f-2.0f*normalized),
        6.0f*normalized*(1.0f-normalized)/(upper-lower)
    );
}

inline float3 crowTerminalPrimaryBroadEdgeTerms(
    float axial,
    float signedWidth,
    uint packedIdentity,
    float4 remex) {
    uint featherClass=packedIdentity&255u;
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    if(featherClass!=1u||order+1u!=count){return float3(1.0f,0.0f,0.0f);}
    axial=clamp(axial,0.0f,1.0f);
    float2 rise=crowSmoothstepTerms(axial,0.40f,0.50f);
    float2 fall=crowSmoothstepTerms(axial,0.625f,0.725f);
    float axialEnvelope=rise.x*(1.0f-fall.x);
    float axialEnvelopeDerivative=rise.y*(1.0f-fall.x)-rise.x*fall.y;
    float broadEdgeCoordinate=-signedWidth*remex.y;
    float2 edge=crowSmoothstepTerms(broadEdgeCoordinate,0.0f,1.0f);
    float edgeSignedWidthDerivative=-remex.y*edge.y;
    constexpr float amplitude=0.40f;
    return float3(
        1.0f+amplitude*axialEnvelope*edge.x,
        amplitude*axialEnvelopeDerivative*edge.x,
        amplitude*axialEnvelope*edgeSignedWidthDerivative
    );
}

inline float3 crowTerminalFoldedRemexJunctionTerms(
    float axial,
    float signedWidth,
    uint packedIdentity,
    float4 remex) {
    uint featherClass=packedIdentity&255u;
    uint order=(packedIdentity>>16u)&255u;
    uint count=max((packedIdentity>>24u)&255u,1u);
    bool isPrimary=featherClass==1u;
    if((!isPrimary&&featherClass!=2u)||order+1u!=count){
        return float3(1.0f,0.0f,0.0f);
    }
    axial=clamp(axial,0.0f,1.0f);
    float2 rise=crowSmoothstepTerms(
        axial,isPrimary?0.16f:0.38f,isPrimary?0.25f:0.50f
    );
    float2 fall=crowSmoothstepTerms(
        axial,isPrimary?0.375f:0.75f,isPrimary?0.46f:0.84f
    );
    float axialEnvelope=rise.x*(1.0f-fall.x);
    float axialEnvelopeDerivative=rise.y*(1.0f-fall.x)-rise.x*fall.y;
    float edgeSign=isPrimary?1.0f:-1.0f;
    float junctionEdgeCoordinate=edgeSign*signedWidth*remex.y;
    float2 edge=crowSmoothstepTerms(junctionEdgeCoordinate,0.0f,1.0f);
    float edgeSignedWidthDerivative=edgeSign*remex.y*edge.y;
    float amplitude=isPrimary?0.35f:0.28f;
    return float3(
        1.0f+amplitude*axialEnvelope*edge.x,
        amplitude*axialEnvelopeDerivative*edge.x,
        amplitude*axialEnvelope*edgeSignedWidthDerivative
    );
}

inline float3 crowRectrixEdgeMicrostructure(
    float axial,
    float signedWidth,
    float4 rectrix) {
    axial=clamp(axial,0.0f,1.0f);
    float sine=max(sin(M_PI_F*axial),0.0f);
    float cosine=cos(M_PI_F*axial);
    float sinePower=pow(sine,0.9f);
    float distalBias=0.35f+0.65f*axial;
    float envelope=sinePower*distalBias;
    float envelopeDerivative=0.9f*pow(max(sine,1.0e-6f),-0.1f)
        *M_PI_F*cosine*distalBias+0.65f*sinePower;
    float phase=0.55f+3.2f*rectrix.x+0.45f*signedWidth*rectrix.y;
    float firstAngle=10.0f*M_PI_F*axial+phase;
    float secondAngle=22.0f*M_PI_F*axial-0.7f*phase;
    float wave=0.68f*sin(firstAngle)+0.32f*sin(secondAngle);
    float waveAxialDerivative=0.68f*10.0f*M_PI_F*cos(firstAngle)
        +0.32f*22.0f*M_PI_F*cos(secondAngle);
    float phaseSignedWidthDerivative=0.45f*rectrix.y;
    float waveSignedWidthDerivative=0.68f*cos(firstAngle)
        *phaseSignedWidthDerivative
        -0.32f*0.7f*cos(secondAngle)*phaseSignedWidthDerivative;
    float amplitude=0.018f+0.008f*rectrix.x;
    return float3(
        1.0f+amplitude*envelope*wave,
        amplitude*(envelopeDerivative*wave+envelope*waveAxialDerivative),
        amplitude*envelope*waveSignedWidthDerivative
    );
}

inline float crowFeatherCrownRatio(uint packedIdentity) {
    uint featherClass=packedIdentity&255u;
    if(featherClass==3u){
        float radialFraction=crowRectrixVaneProfile(packedIdentity).x;
        return 0.105f+0.020f*(1.0f-radialFraction);
    }
    if(featherClass==1u||featherClass==2u){
        float fraction=crowRemexVaneProfile(packedIdentity).x;
        return featherClass==1u
            ?0.122f-0.018f*fraction
            :0.158f-0.012f*fraction;
    }
    if(crowIsLiveCovert(featherClass)){
        return crowCovertVaneProfile1(
            crowCovertVaneProfile0(packedIdentity)
        ).y;
    }
    return featherClass==1u?0.13f:(featherClass==2u?0.16f:0.14f);
}

inline float crowFeatherRootWidthRatio(uint packedIdentity) {
    uint featherClass=packedIdentity&255u;
    return crowIsLiveCovert(featherClass)
        ?crowCovertRootWidthRatio(
            packedIdentity,crowCovertVaneProfile0(packedIdentity)
        )
        :0.55f;
}

inline float3 crowFeatherPosition(
    float3 root,
    float3 direction,
    float3 surfaceNormal,
    float lengthMeters,
    float maximumWidthMeters,
    float camberMeters,
    float axial,
    float signedWidth,
    uint packedIdentity) {
    uint featherClass=packedIdentity&255u;
    float geometryAxial=crowTrailingCovertGlobalAxial(featherClass,axial);
    float4 rectrix=crowRectrixVaneProfile(packedIdentity);
    float4 remex=crowRemexVaneProfile(packedIdentity);
    float4 covert=crowCovertVaneProfile0(packedIdentity);
    float4 covertMorphology=crowCovertVaneProfile1(covert);
    float shapedAxial=max(
        0.0f,
        geometryAxial-(featherClass==3u
            ?crowRectrixTerminalRoundback(geometryAxial,signedWidth,rectrix)
            :0.0f)
    );
    float3 tangent=safeNormalizeCrow(direction,float3(1,0,0));
    float3 orthogonalNormal=safeNormalizeCrow(
        surfaceNormal-tangent*dot(surfaceNormal,tangent),surfaceNormal
    );
    float3 widthAxis=safeNormalizeCrow(
        cross(orthogonalNormal,tangent),float3(0,1,0)
    );
    float rootWidthRatio=crowFeatherRootWidthRatio(packedIdentity);
    float symmetricWidth=mix(
        rootWidthRatio*maximumWidthMeters,maximumWidthMeters,shapedAxial
    )
        *(featherClass==3u
            ?crowRectrixTerminalWidthEnvelope(shapedAxial,rectrix)
            :crowFeatherWidthEnvelope(shapedAxial));
    float vaneAsymmetry=featherClass==3u?rectrix.z:
        ((featherClass==1u||featherClass==2u)?remex.z:
            (crowIsLiveCovert(featherClass)?covert.w:0.0f));
    float narrowSignedWidth=featherClass==3u?rectrix.y:
        ((featherClass==1u||featherClass==2u)?remex.y:
            (crowIsLiveCovert(featherClass)?covert.z:0.0f));
    float sideScale=1.0f-vaneAsymmetry*signedWidth*narrowSignedWidth;
    float edgeModulation=featherClass==3u
        ?crowRectrixEdgeMicrostructure(shapedAxial,signedWidth,rectrix).x
        :((featherClass==1u||featherClass==2u)
            ?crowRemexEdgeMicrostructure(
                shapedAxial,signedWidth,packedIdentity,remex
            ).x:(crowIsLiveCovert(featherClass)
                ?crowCovertEdgeMicrostructure(
                    shapedAxial,signedWidth,covert,covertMorphology
                ).x:1.0f));
    float broadEdgeScale=crowTerminalPrimaryBroadEdgeTerms(
        geometryAxial,signedWidth,packedIdentity,remex
    ).x;
    float foldedJunctionScale=crowTerminalFoldedRemexJunctionTerms(
        geometryAxial,signedWidth,packedIdentity,remex
    ).x;
    float width=symmetricWidth*sideScale*edgeModulation*broadEdgeScale
        *foldedJunctionScale*crowTrailingCovertCoverage(featherClass,axial);
    float camberSkew=featherClass==3u?rectrix.w:
        ((featherClass==1u||featherClass==2u)
            ?remex.w:(crowIsLiveCovert(featherClass)
                ?covertMorphology.x:0.0f));
    float camberEnvelope=sin(M_PI_F*shapedAxial)
        *(1.0f+camberSkew*(2.0f*shapedAxial-1.0f));
    float3 center=root+tangent*(lengthMeters*shapedAxial)
        +orthogonalNormal*(camberMeters*camberEnvelope
            +crowTrailingCovertNormalOffset(featherClass,axial));
    float transverseEnvelope=max(0.0f,1.0f-signedWidth*signedWidth);
    float crownEnvelope=pow(max(sin(M_PI_F*shapedAxial),0.0f),0.65f);
    float crown=crowFeatherCrownRatio(packedIdentity)*width
        *transverseEnvelope*crownEnvelope;
    return center+widthAxis*(signedWidth*width)+orthogonalNormal*crown;
}

inline float3 crowFeatherNormal(
    float3 direction,
    float3 surfaceNormal,
    float lengthMeters,
    float maximumWidthMeters,
    float camberMeters,
    float axial,
    float signedWidth,
    uint packedIdentity) {
    uint featherClass=packedIdentity&255u;
    if(featherClass==3u||crowIsTrailingCovertRank(featherClass)){
        // Match the retained mesh chord instead of a cancellation-prone
        // sub-vertex delta at rounded terminal edges.
        float axialEpsilon=featherClass==3u?1.0f/48.0f:0.0005f;
        float widthEpsilon=featherClass==3u?1.0f:0.0005f;
        float firstAxial=max(0.0f,axial-axialEpsilon);
        float secondAxial=min(1.0f,axial+axialEpsilon);
        float firstWidth=max(-1.0f,signedWidth-widthEpsilon);
        float secondWidth=min(1.0f,signedWidth+widthEpsilon);
        float3 axialFirst=crowFeatherPosition(
            float3(0),direction,surfaceNormal,lengthMeters,
            maximumWidthMeters,camberMeters,firstAxial,signedWidth,
            packedIdentity
        );
        float3 axialSecond=crowFeatherPosition(
            float3(0),direction,surfaceNormal,lengthMeters,
            maximumWidthMeters,camberMeters,secondAxial,signedWidth,
            packedIdentity
        );
        float3 widthFirst=crowFeatherPosition(
            float3(0),direction,surfaceNormal,lengthMeters,
            maximumWidthMeters,camberMeters,axial,firstWidth,packedIdentity
        );
        float3 widthSecond=crowFeatherPosition(
            float3(0),direction,surfaceNormal,lengthMeters,
            maximumWidthMeters,camberMeters,axial,secondWidth,packedIdentity
        );
        float3 resolved=safeNormalizeCrow(
            cross(axialSecond-axialFirst,widthSecond-widthFirst),surfaceNormal
        );
        return dot(resolved,surfaceNormal)<0.0f?-resolved:resolved;
    }
    float3 tangent=safeNormalizeCrow(direction,float3(1,0,0));
    float3 orthogonalNormal=safeNormalizeCrow(
        surfaceNormal-tangent*dot(surfaceNormal,tangent),surfaceNormal
    );
    float3 widthAxis=safeNormalizeCrow(
        cross(orthogonalNormal,tangent),float3(0,1,0)
    );
    float sampledAxial=clamp(axial,1.0e-4f,1.0f-1.0e-4f);
    float sine=max(sin(M_PI_F*sampledAxial),1.0e-5f);
    float cosine=cos(M_PI_F*sampledAxial);
    float sineDerivative=M_PI_F*cosine;
    float bodyEnvelope=0.32f+0.68f*pow(sine,0.58f);
    float bodyDerivative=0.68f*0.58f*pow(sine,-0.42f)*sineDerivative;
    float tipTaper=1.0f-0.985f*pow(sampledAxial,3.2f);
    float tipDerivative=-0.985f*3.2f*pow(sampledAxial,2.2f);
    float rootWidthRatio=crowFeatherRootWidthRatio(packedIdentity);
    float baseWidth=maximumWidthMeters
        *(rootWidthRatio+(1.0f-rootWidthRatio)*sampledAxial);
    float baseWidthDerivative=(1.0f-rootWidthRatio)*maximumWidthMeters;
    float symmetricWidth=baseWidth*bodyEnvelope*tipTaper;
    float symmetricWidthDerivative=baseWidthDerivative*bodyEnvelope*tipTaper
        +baseWidth*bodyDerivative*tipTaper
        +baseWidth*bodyEnvelope*tipDerivative;
    float4 rectrix=crowRectrixVaneProfile(packedIdentity);
    float4 remex=crowRemexVaneProfile(packedIdentity);
    float4 covert=crowCovertVaneProfile0(packedIdentity);
    float4 covertMorphology=crowCovertVaneProfile1(covert);
    float vaneAsymmetry=featherClass==3u?rectrix.z:
        ((featherClass==1u||featherClass==2u)?remex.z:
            (crowIsLiveCovert(featherClass)?covert.w:0.0f));
    float narrowSignedWidth=featherClass==3u?rectrix.y:
        ((featherClass==1u||featherClass==2u)?remex.y:
            (crowIsLiveCovert(featherClass)?covert.z:0.0f));
    float sideScale=1.0f-vaneAsymmetry*signedWidth*narrowSignedWidth;
    float3 edgeMicrostructure=featherClass==3u
        ?crowRectrixEdgeMicrostructure(sampledAxial,signedWidth,rectrix)
        :((featherClass==1u||featherClass==2u)
            ?crowRemexEdgeMicrostructure(
                sampledAxial,signedWidth,packedIdentity,remex
            ):(crowIsLiveCovert(featherClass)
                ?crowCovertEdgeMicrostructure(
                    sampledAxial,signedWidth,covert,covertMorphology
                ):float3(1.0f,0.0f,0.0f)));
    float3 broadEdge=crowTerminalPrimaryBroadEdgeTerms(
        sampledAxial,signedWidth,packedIdentity,remex
    );
    float3 foldedJunction=crowTerminalFoldedRemexJunctionTerms(
        sampledAxial,signedWidth,packedIdentity,remex
    );
    float identityScale=broadEdge.x*foldedJunction.x;
    float identityAxialDerivative=broadEdge.y*foldedJunction.x
        +broadEdge.x*foldedJunction.y;
    float identitySignedWidthDerivative=broadEdge.z*foldedJunction.x
        +broadEdge.x*foldedJunction.z;
    float combinedModulation=edgeMicrostructure.x*identityScale;
    float combinedAxialDerivative=edgeMicrostructure.y*identityScale
        +edgeMicrostructure.x*identityAxialDerivative;
    float combinedSignedWidthDerivative=edgeMicrostructure.z*identityScale
        +edgeMicrostructure.x*identitySignedWidthDerivative;
    float width=symmetricWidth*sideScale*combinedModulation;
    float widthDerivative=sideScale*(
        symmetricWidthDerivative*combinedModulation
        +symmetricWidth*combinedAxialDerivative
    );
    float widthSignedDerivative=symmetricWidth*(
        -vaneAsymmetry*narrowSignedWidth*combinedModulation
        +sideScale*combinedSignedWidthDerivative
    );
    float crownEnvelope=pow(sine,0.65f);
    float crownDerivative=0.65f*pow(sine,-0.35f)*sineDerivative;
    float transverseEnvelope=max(0.0f,1.0f-signedWidth*signedWidth);
    float crownRatio=crowFeatherCrownRatio(packedIdentity);
    float camberSkew=featherClass==3u?rectrix.w:
        ((featherClass==1u||featherClass==2u)
            ?remex.w:(crowIsLiveCovert(featherClass)
                ?covertMorphology.x:0.0f));
    float camberDerivative=sineDerivative
        *(1.0f+camberSkew*(2.0f*sampledAxial-1.0f))
        +sine*2.0f*camberSkew;
    float3 axialTangent=tangent*lengthMeters
        +orthogonalNormal*(camberMeters*camberDerivative)
        +widthAxis*(signedWidth*widthDerivative)
        +orthogonalNormal*(crownRatio*transverseEnvelope
            *(widthDerivative*crownEnvelope+width*crownDerivative));
    float3 widthTangent=widthAxis*(width+signedWidth*widthSignedDerivative)
        +orthogonalNormal*(crownRatio*crownEnvelope
            *(widthSignedDerivative*transverseEnvelope
                +width*(-2.0f*signedWidth)));
    float3 result=safeNormalizeCrow(
        cross(axialTangent,widthTangent),surfaceNormal
    );
    return dot(result,surfaceNormal)<0.0f?-result:result;
}

inline float3 crowFeatherDetailPosition(
    float3 root,
    float3 direction,
    float3 surfaceNormal,
    float lengthMeters,
    float maximumWidthMeters,
    float camberMeters,
    float rachisRadiusMeters,
    float axial,
    float signedWidth,
    float detailKind,
    float ribbonSide,
    uint packedIdentity) {
    float3 base=crowFeatherPosition(
        root,direction,surfaceNormal,lengthMeters,maximumWidthMeters,
        camberMeters,axial,signedWidth,packedIdentity
    );
    if(detailKind<0.5f){return base;}
    float3 tangent=safeNormalizeCrow(direction,float3(1,0,0));
    float3 baseNormal=crowFeatherNormal(
        direction,surfaceNormal,lengthMeters,maximumWidthMeters,camberMeters,
        axial,signedWidth,packedIdentity
    );
    float3 widthAxis=safeNormalizeCrow(
        cross(baseNormal,tangent),float3(0,1,0)
    );
    if(detailKind<1.5f){
        float halfWidth=max(
            0.00011f,rachisRadiusMeters*(0.96f-0.72f*axial)
        );
        return base+baseNormal*(0.34f*halfWidth)
            +widthAxis*(ribbonSide*halfWidth);
    }
    float barbSign=signedWidth<0.0f?-1.0f:1.0f;
    float3 barbDirection=safeNormalizeCrow(
        widthAxis*barbSign+tangent*0.16f,widthAxis
    );
    float3 ribbonAxis=safeNormalizeCrow(
        cross(baseNormal,barbDirection),tangent
    );
    uint featherClass=packedIdentity&255u;
    uint featherOrder=(packedIdentity>>16u)&255u;
    uint featherCount=max((packedIdentity>>24u)&255u,1u);
    float terminalPrimaryBarbScale=
        featherClass==1u&&featherOrder+1u==featherCount?1.80f:1.0f;
    float halfWidth=0.00010f*(1.0f-0.28f*axial)
        *terminalPrimaryBarbScale;
    return base+baseNormal*0.00010f
        +ribbonAxis*(ribbonSide*halfWidth);
}

inline float3 crowFeatherDetailNormal(
    float3 direction,
    float3 surfaceNormal,
    float lengthMeters,
    float maximumWidthMeters,
    float camberMeters,
    float axial,
    float signedWidth,
    float detailKind,
    float ribbonSide,
    uint packedIdentity) {
    float3 baseNormal=crowFeatherNormal(
        direction,surfaceNormal,lengthMeters,maximumWidthMeters,camberMeters,
        axial,signedWidth,packedIdentity
    );
    if(detailKind<0.5f){return baseNormal;}
    float3 tangent=safeNormalizeCrow(direction,float3(1,0,0));
    float3 widthAxis=safeNormalizeCrow(
        cross(baseNormal,tangent),float3(0,1,0)
    );
    if(detailKind<1.5f){
        return safeNormalizeCrow(
            baseNormal-widthAxis*(0.38f*ribbonSide),baseNormal
        );
    }
    float barbSign=signedWidth<0.0f?-1.0f:1.0f;
    float3 barbDirection=safeNormalizeCrow(
        widthAxis*barbSign+tangent*0.16f,widthAxis
    );
    float3 ribbonAxis=safeNormalizeCrow(
        cross(baseNormal,barbDirection),tangent
    );
    return safeNormalizeCrow(
        baseNormal-ribbonAxis*(0.24f*ribbonSide),baseNormal
    );
}

struct CrowFeatherDrawArguments {
    uint vertexCount; uint instanceCount; uint vertexStart; uint baseInstance;
};

struct CrowFeatherDispatchArguments {
    uint threadgroupsPerGrid[3];
};

kernel void prepareCrowFeatherIndirectWork(
    device CrowFeatherDrawArguments* drawArguments [[buffer(0)]],
    device CrowFeatherDispatchArguments* dispatchArguments [[buffer(1)]],
    constant CrowFeatherGeometryUniforms& uniforms [[buffer(2)]],
    constant uint& threadsPerThreadgroup [[buffer(3)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u){return;}
    float detailTier=uniforms.renderOffsetAndDetailScale.w;
    bool gpuSelectedDetailDensity=uniforms.counts.w>0u;
    uint selectedTemplateVertexCount=!gpuSelectedDetailDensity
        ?uniforms.counts.y
        :(detailTier>=1.5f?uniforms.counts.y:
            (detailTier>=0.5f?uniforms.counts.w+24u*6u:uniforms.counts.w));
    uint selectedVertexCount=uniforms.counts.x*selectedTemplateVertexCount;
    drawArguments[0].vertexCount=selectedVertexCount;
    drawArguments[0].instanceCount=1u;
    drawArguments[0].vertexStart=0u;
    drawArguments[0].baseInstance=0u;
    dispatchArguments[0].threadgroupsPerGrid[0]=
        (selectedVertexCount+threadsPerThreadgroup-1u)/threadsPerThreadgroup;
    dispatchArguments[0].threadgroupsPerGrid[1]=1u;
    dispatchArguments[0].threadgroupsPerGrid[2]=1u;
}

kernel void deformCrowFeatherTemplates(
    device const CrowFeatherTemplateVertexGPU* templateVertices [[buffer(0)]],
    device const CrowFeatherRootStateGPU* roots [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    constant CrowFeatherGeometryUniforms& uniforms [[buffer(3)]],
    uint outputIndex [[thread_position_in_grid]]) {
    uint outputCount=uniforms.counts.z;
    if(outputIndex>=outputCount){return;}
    uint featherCount=uniforms.counts.x;
    uint templateVertexCount=uniforms.counts.y;
    bool gpuSelectedDetailDensity=uniforms.counts.w>0u;
    bool densityOrdered=gpuSelectedDetailDensity
        &&uniforms.renderOffsetAndDetailScale.w<1.5f;
    uint triangleInstance=outputIndex/3u;
    uint featherIndex=densityOrdered
        ?triangleInstance%featherCount:outputIndex/templateVertexCount;
    uint templateIndex=densityOrdered
        ?(triangleInstance/featherCount)*3u+outputIndex%3u
        :outputIndex-featherIndex*templateVertexCount;
    CrowFeatherRootStateGPU root=roots[featherIndex];
    float4 parameter=templateVertices[templateIndex].parameters;
    bool isRemexBarbSupplement=parameter.z>2.5f;
    float geometryDetailKind=isRemexBarbSupplement?2.0f:parameter.z;
    float3 currentDirection=root.currentDirectionAndRachis.xyz;
    float3 previousDirection=root.previousDirectionAndCamber.xyz;
    float3 currentNormal=root.currentNormalAndPadding.xyz;
    float3 previousNormal=root.previousNormalAndPadding.xyz;
    float lengthMeters=root.currentPositionAndLength.w;
    float maximumWidthMeters=root.previousPositionAndWidth.w;
    float camberMeters=root.previousDirectionAndCamber.w;
    float previousLengthMeters=root.previousMorphology.x;
    float previousMaximumWidthMeters=root.previousMorphology.y;
    float previousRachisRadiusMeters=root.previousMorphology.z;
    float previousCamberMeters=root.previousMorphology.w;
    uint packedIdentity=root.identity.w;
    uint featherClass=packedIdentity&255u;
    bool isUnderwingCovert=featherClass==12u||featherClass==13u;
    bool isLiveCovert=crowIsLiveCovert(featherClass);
    bool isRectrixBarb=featherClass==3u&&geometryDetailKind>1.5f;
    bool temporallyVariableMorphology=isLiveCovert;
    bool detailEnabled=parameter.z<0.5f
        ||(uniforms.renderOffsetAndDetailScale.w>=geometryDetailKind
            &&(isRemexBarbSupplement
                ?(featherClass==1u||featherClass==2u)
                :(featherClass==1u||featherClass==2u||isLiveCovert
                    ||isRectrixBarb)));
    float3 current=detailEnabled
        ?crowFeatherDetailPosition(
            root.currentPositionAndLength.xyz,currentDirection,currentNormal,
            lengthMeters,maximumWidthMeters,camberMeters,
            root.currentDirectionAndRachis.w,parameter.x,parameter.y,
            geometryDetailKind,parameter.w,packedIdentity
        )
        :root.currentPositionAndLength.xyz;
    float3 previous=detailEnabled
        ?crowFeatherDetailPosition(
            root.previousPositionAndWidth.xyz,previousDirection,previousNormal,
            temporallyVariableMorphology?previousLengthMeters:lengthMeters,
            temporallyVariableMorphology
                ?previousMaximumWidthMeters:maximumWidthMeters,
            temporallyVariableMorphology?previousCamberMeters:camberMeters,
            temporallyVariableMorphology
                ?previousRachisRadiusMeters:root.currentDirectionAndRachis.w,
            parameter.x,parameter.y,
            geometryDetailKind,parameter.w,packedIdentity
        )
        :root.previousPositionAndWidth.xyz;
    current+=uniforms.renderOffsetAndDetailScale.xyz;
    previous+=uniforms.renderOffsetAndDetailScale.xyz;
    float3 deformedNormal=detailEnabled
        ?crowFeatherDetailNormal(
            currentDirection,currentNormal,lengthMeters,maximumWidthMeters,
            camberMeters,parameter.x,parameter.y,geometryDetailKind,parameter.w,
            packedIdentity
        ):currentNormal;
    float material=featherClass==1u?0.25f:
        (featherClass==2u?0.22f:(isUnderwingCovert?0.17f:0.23f));
    float shade=isUnderwingCovert
        ?0.0066f+0.00022f*float(root.identity.x%9u)
        :0.0075f+0.00045f*float(root.identity.x%11u);
    float greenScale=isUnderwingCovert?1.45f:1.28f;
    float blueScale=isUnderwingCovert?2.55f:1.72f;
    float detailShadeScale=geometryDetailKind>0.5f
        ?(geometryDetailKind<1.5f?1.18f:1.08f):1.0f;
    CrowFeatherVertexGPU result;
    result.position=float4(current,1);
    result.normal=float4(deformedNormal,0);
    result.color=float4(
        shade*detailShadeScale,shade*greenScale*detailShadeScale,
        shade*blueScale*detailShadeScale,material
    );
    result.previousPosition=float4(previous,1);
    result.identity=root.identity;
    result.parameters=float4(
        crowTrailingCovertGlobalAxial(featherClass,parameter.x),
        parameter.y,float(featherClass),detailEnabled?geometryDetailKind:parameter.z
    );
    output[outputIndex]=result;
}

inline float crowVentralRachisHalfWidth(
    thread const CrowVentralRachisCurveRecordGPU& record,
    float axial) {
    float t=clamp(axial,0.0f,1.0f);
    float rootEnvelope=record.widthsEnvelopeAndAsymmetry.z;
    float bodyEnvelope=rootEnvelope+(1.0f-rootEnvelope)
        *pow(max(sin(M_PI_F*t),0.0f),0.58f);
    float tipTaper=1.0f-0.985f*pow(t,3.2f);
    float rippleEnvelope=pow(max(sin(M_PI_F*t),0.0f),2.0f);
    float edgeRipple=1.0f+record.edgeRippleAndMaterial.x
        *sin(2.0f*M_PI_F*record.edgeRippleAndMaterial.z*t
            +record.edgeRippleAndMaterial.y)*rippleEnvelope;
    return mix(
        record.widthsEnvelopeAndAsymmetry.x,
        record.widthsEnvelopeAndAsymmetry.y,
        t
    )*bodyEnvelope*tipTaper*edgeRipple;
}

inline float crowVentralBarbHalfWidth(
    thread const CrowVentralRachisCurveRecordGPU& record,
    float axial,float signedWidth) {
    return crowVentralRachisHalfWidth(record,axial)
        *(1.0f+record.widthsEnvelopeAndAsymmetry.w
            *clamp(signedWidth,-1.0f,1.0f));
}

inline float3 crowVentralRachisCenter(
    thread const CrowVentralRachisCurveRecordGPU& record,
    float axial) {
    float t=clamp(axial,0.0f,1.0f);
    float halfWidth=crowVentralRachisHalfWidth(record,t);
    float3 direction=safeNormalizeCrow(
        record.tipAndCamber.xyz-record.rootAndPennaceousStart.xyz,
        float3(-1,0,0));
    float3 widthAxis=safeNormalizeCrow(
        cross(record.normalAndTransverseCamber.xyz,direction),
        float3(0,1,0));
    return mix(record.rootAndPennaceousStart.xyz,record.tipAndCamber.xyz,t)
        +widthAxis*(record.lateralSweepAndReserved.x*sin(M_PI_F*t))
        +record.normalAndTransverseCamber.xyz
        *(record.tipAndCamber.w*sin(M_PI_F*t)
            +record.normalAndTransverseCamber.w*halfWidth+0.00012f);
}

inline float crowVentralRachisRadius(float axial) {
    return mix(0.00022f,0.000055f,axial);
}

inline float3 crowVentralRachisTubePoint(
    float3 start,
    float3 end,
    float startRadius,
    float endRadius,
    uint radialIndex,
    uint corner) {
    float3 axis=safeNormalizeCrow(end-start,float3(0,0,1));
    float3 helper=abs(axis.z)<0.82f?float3(0,0,1):float3(0,1,0);
    float3 first=safeNormalizeCrow(cross(axis,helper),float3(1,0,0));
    float3 second=safeNormalizeCrow(cross(axis,first),float3(0,1,0));
    uint next=(radialIndex+1u)%4u;
    float angle0=2.0f*M_PI_F*float(radialIndex)/4.0f;
    float angle1=2.0f*M_PI_F*float(next)/4.0f;
    float3 radial0=cos(angle0)*first+sin(angle0)*second;
    float3 radial1=cos(angle1)*first+sin(angle1)*second;
    float3 points[4]={
        start+startRadius*radial0,
        start+startRadius*radial1,
        end+endRadius*radial1,
        end+endRadius*radial0
    };
    return points[corner];
}

kernel void expandCrowVentralRachisCurves(
    device const CrowVentralRachisCurveRecordGPU* records [[buffer(0)]],
    device const CrowVentralRachisSegmentWorkGPU* work [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    constant CrowVentralRachisGeometryUniforms& uniforms [[buffer(3)]],
    uint outputIndex [[thread_position_in_grid]]) {
    uint verticesPerInterval=uniforms.counts.z;
    uint outputCount=uniforms.counts.y*verticesPerInterval;
    if(outputIndex>=outputCount){return;}
    uint workIndex=outputIndex/verticesPerInterval;
    uint localVertex=outputIndex-workIndex*verticesPerInterval;
    CrowVentralRachisSegmentWorkGPU selected=work[workIndex];
    CrowVentralRachisCurveRecordGPU record=records[selected.indices.x];
    float sectionCount=max(float(selected.indices.z),1.0f);
    float localFirst=float(selected.indices.y)/sectionCount;
    float localSecond=float(selected.indices.y+1u)/sectionCount;
    float pennaceousStart=record.rootAndPennaceousStart.w;
    float first=mix(pennaceousStart,1.0f,localFirst);
    float second=mix(pennaceousStart,1.0f,localSecond);
    float3 start=crowVentralRachisCenter(record,first);
    float3 end=crowVentralRachisCenter(record,second);
    float startRadius=crowVentralRachisRadius(first);
    float endRadius=crowVentralRachisRadius(second);
    uint triangle=localVertex/3u;
    uint triangleCorner=localVertex%3u;
    uint radialIndex=triangle/2u;
    bool secondTriangle=(triangle&1u)!=0u;
    uint corner=secondTriangle
        ?uint3(0u,2u,3u)[triangleCorner]
        :uint3(0u,1u,2u)[triangleCorner];
    uint3 normalCorners=secondTriangle?uint3(0u,2u,3u):uint3(0u,1u,2u);
    float3 a=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.x
    );
    float3 b=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.y
    );
    float3 c=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.z
    );
    float3 localPosition=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,corner
    );
    float3 normal=safeNormalizeCrow(cross(b-a,c-a),float3(0,0,1));
    float material=record.edgeRippleAndMaterial.w;
    float3 color=float3(
        0.010f*(1.0f+0.06f*material),
        0.014f*(1.0f+0.04f*material),
        0.022f*(1.0f+0.03f*material)
    );
    uint primitiveIdentifier=0x07000000u
        +selected.indices.x*96u+selected.indices.y*8u+triangle+1u;
    CrowFeatherVertexGPU result;
    result.position=float4(localPosition+uniforms.currentBodyCenter.xyz,1);
    result.previousPosition=float4(
        localPosition+uniforms.previousBodyCenter.xyz,1
    );
    result.normal=float4(normal,0);
    result.color=float4(color,0.14f);
    result.identity=uint4(
        0xffffffffu,primitiveIdentifier,2u,uniforms.counts.w
    );
    result.parameters=float4(0.5f,0,0,0);
    output[outputIndex]=result;
}

inline float crowVentralBarbVariation(
    thread const CrowVentralRachisCurveRecordGPU& record,
    uint pairIndex,uint sideIndex,uint salt) {
    uint value=record.identity.x*0xA511E9B3u;
    value^=record.identity.y*0x63D83595u;
    value^=record.identity.z*0x9E3779B9u;
    value^=record.identity.w*0x85EBCA6Bu;
    value^=pairIndex*0xC2B2AE35u;
    value^=sideIndex*0x27D4EB2Fu;
    value^=salt;
    value^=value>>16u;
    value*=0x7FEB352Du;
    value^=value>>15u;
    value*=0x846CA68Bu;
    value^=value>>16u;
    return 2.0f*float(value&0x00ffffffu)/float(0x00ffffffu)-1.0f;
}

inline float3 crowVentralBarbPoint(
    thread const CrowVentralRachisCurveRecordGPU& record,
    uint pairIndex,uint pairCount,float side,float curveFraction) {
    float safePairCount=max(float(pairCount),1.0f);
    uint sideIndex=side<0.0f?0u:1u;
    float attachmentVariation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0x9E3779B9u
    );
    float curvatureVariation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0x85EBCA6Bu
    );
    float spacing=0.77f/(safePairCount+1.0f);
    float localAxial=0.10f+spacing*float(pairIndex+1u)
        +0.24f*spacing*attachmentVariation;
    float localReach=min(
        0.94f,localAxial+0.030f+0.018f*localAxial
            +0.16f*spacing*curvatureVariation
    );
    float pennaceousStart=record.rootAndPennaceousStart.w;
    float firstAxial=mix(pennaceousStart,1.0f,localAxial);
    float secondAxial=mix(pennaceousStart,1.0f,localReach);
    float t=clamp(curveFraction,0.0f,1.0f);
    float axial=mix(firstAxial,secondAxial,t);
    float3 center=crowVentralRachisCenter(record,axial);
    float3 direction=safeNormalizeCrow(
        record.tipAndCamber.xyz-record.rootAndPennaceousStart.xyz,
        float3(-1,0,0));
    float3 widthAxis=safeNormalizeCrow(
        cross(record.normalAndTransverseCamber.xyz,direction),
        float3(0,1,0));
    float halfWidth=crowVentralBarbHalfWidth(record,axial,side);
    float lateralExponent=0.82f+0.08f*curvatureVariation;
    float lateralFraction=(0.955f+0.012f*attachmentVariation)
        *pow(t,lateralExponent);
    float crownSeparation=0.000030f
        +(0.000022f+0.000008f*curvatureVariation)*sin(M_PI_F*t);
    return center+side*widthAxis*halfWidth*lateralFraction
        +record.normalAndTransverseCamber.xyz*crownSeparation;
}

inline float crowVentralBarbRadius(
    thread const CrowVentralRachisCurveRecordGPU& record,
    uint pairIndex,uint sideIndex,float curveFraction) {
    float variation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0xC2B2AE35u
    );
    float t=clamp(curveFraction,0.0f,1.0f);
    return (1.0f+0.12f*variation)
        *mix(0.000026f,0.000004f,pow(t,0.88f));
}

inline float2 crowVentralBarbuleVaneCoordinates(
    thread const CrowVentralRachisCurveRecordGPU& record,
    uint pairIndex,uint pairCount,uint sideIndex,
    uint barbuleIndex,uint barbuleCount,uint branchIndex,
    float segmentFraction) {
    float safePairCount=max(float(pairCount),1.0f);
    float attachmentVariation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0x9E3779B9u
    );
    float curvatureVariation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0x85EBCA6Bu
    );
    float spacing=0.77f/(safePairCount+1.0f);
    float localAxial=0.10f+spacing*float(pairIndex+1u)
        +0.24f*spacing*attachmentVariation;
    float localReach=min(
        0.94f,localAxial+0.030f+0.018f*localAxial
            +0.16f*spacing*curvatureVariation
    );
    float pennaceousStart=record.rootAndPennaceousStart.w;
    float firstAxial=mix(pennaceousStart,1.0f,localAxial);
    float secondAxial=mix(pennaceousStart,1.0f,localReach);
    float barbuleFraction=float(barbuleIndex+1u)
        /float(max(barbuleCount,1u)+1u);
    float rootFraction=0.10f+0.78f*barbuleFraction;
    float rootAxial=mix(firstAxial,secondAxial,rootFraction);
    float branchSign=branchIndex==0u?-1.0f:1.0f;
    float axialSpacing=(1.0f-pennaceousStart)*spacing;
    float targetAxial=clamp(
        rootAxial+0.46f*branchSign*axialSpacing,
        pennaceousStart+0.015f,0.96f
    );
    float lateralExponent=0.82f+0.08f*curvatureVariation;
    float rootLateral=(0.955f+0.012f*attachmentVariation)
        *pow(rootFraction,lateralExponent);
    float side=sideIndex==0u?-1.0f:1.0f;
    float targetLateral=min(
        0.93f,rootLateral*(0.985f+0.012f*branchSign*side)
    );
    float t=clamp(segmentFraction,0.0f,1.0f);
    return float2(
        mix(rootAxial,targetAxial,t),
        side*mix(rootLateral,targetLateral,t)
    );
}

inline float3 crowVentralBarbulePoint(
    thread const CrowVentralRachisCurveRecordGPU& record,
    uint pairIndex,uint pairCount,uint sideIndex,
    uint barbuleIndex,uint barbuleCount,uint branchIndex,
    float segmentFraction) {
    float2 coordinates=crowVentralBarbuleVaneCoordinates(
        record,pairIndex,pairCount,sideIndex,
        barbuleIndex,barbuleCount,branchIndex,segmentFraction
    );
    float side=coordinates.y<0.0f?-1.0f:1.0f;
    float3 direction=safeNormalizeCrow(
        record.tipAndCamber.xyz-record.rootAndPennaceousStart.xyz,
        float3(-1,0,0));
    float3 widthAxis=safeNormalizeCrow(
        cross(record.normalAndTransverseCamber.xyz,direction),
        float3(0,1,0));
    float halfWidth=crowVentralBarbHalfWidth(record,coordinates.x,side);
    float curvatureVariation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0x85EBCA6Bu
    );
    float barbuleFraction=float(barbuleIndex+1u)
        /float(max(barbuleCount,1u)+1u);
    float rootFraction=0.10f+0.78f*barbuleFraction;
    float crownSeparation=0.000030f
        +(0.000022f+0.000008f*curvatureVariation)
            *sin(M_PI_F*rootFraction);
    float branchLift=branchIndex==0u?0.000005f:0.000016f;
    float t=clamp(segmentFraction,0.0f,1.0f);
    return crowVentralRachisCenter(record,coordinates.x)
        +widthAxis*halfWidth*coordinates.y
        +record.normalAndTransverseCamber.xyz
            *(crownSeparation+t*branchLift);
}

inline float crowVentralBarbuleRadius(
    thread const CrowVentralRachisCurveRecordGPU& record,
    uint pairIndex,uint sideIndex,uint barbuleIndex,float segmentFraction) {
    float variation=crowVentralBarbVariation(
        record,pairIndex,sideIndex,0x165667B1u+barbuleIndex
    );
    float t=clamp(segmentFraction,0.0f,1.0f);
    return (1.0f+0.10f*variation)*mix(0.000012f,0.000004f,t);
}

inline float crowVentralBarbuleLocalOcclusion(
    uint barbuleIndex,uint barbuleCount,uint branchIndex) {
    float fraction=float(barbuleIndex+1u)/float(max(barbuleCount,1u)+1u);
    float edge=abs(2.0f*fraction-1.0f);
    return branchIndex==0u?0.82f+0.08f*edge:0.93f+0.05f*edge;
}

inline bool crowVentralBarbInsidePlane(
    float4 plane,float3 center,float radius) {
    return dot(plane.xyz,center)+plane.w>=-radius;
}

inline float crowVentralLODReferenceLength(
    thread const CrowVentralRachisCurveRecordGPU& record) {
    float retained=record.lateralSweepAndReserved.y;
    return retained>0.0f?retained:distance(
        record.rootAndPennaceousStart.xyz,record.tipAndCamber.xyz
    );
}

inline bool crowVentralBarbRecordVisible(
    thread const CrowVentralRachisCurveRecordGPU& record,
    constant CrowVentralBarbVisibilityUniforms& uniforms) {
    float3 root=record.rootAndPennaceousStart.xyz;
    float3 tip=record.tipAndCamber.xyz;
    float featherLength=distance(root,tip);
    if(crowVentralLODReferenceLength(record)*uniforms.selection.x
        <uniforms.selection.y){return false;}
    float maximumWidth=record.widthsEnvelopeAndAsymmetry.y
        *(1.0f+abs(record.widthsEnvelopeAndAsymmetry.w));
    float radius=0.5f*featherLength+maximumWidth
        +abs(record.tipAndCamber.w)
        +abs(record.normalAndTransverseCamber.w)*maximumWidth
        +abs(record.lateralSweepAndReserved.x)
        +uniforms.bodyCenterAndPadding.w;
    float3 center=0.5f*(root+tip)+uniforms.bodyCenterAndPadding.xyz;
    return crowVentralBarbInsidePlane(uniforms.leftPlane,center,radius)
        &&crowVentralBarbInsidePlane(uniforms.rightPlane,center,radius)
        &&crowVentralBarbInsidePlane(uniforms.bottomPlane,center,radius)
        &&crowVentralBarbInsidePlane(uniforms.topPlane,center,radius)
        &&crowVentralBarbInsidePlane(uniforms.nearPlane,center,radius)
        &&crowVentralBarbInsidePlane(uniforms.farPlane,center,radius);
}

inline bool crowVentralBarbRecordOccluded(
    thread const CrowVentralRachisCurveRecordGPU& record,
    constant CrowVentralBarbVisibilityUniforms& uniforms,
    texture2d<float,access::read> previousDepth) {
    if(uniforms.occlusionViewportBiasAndEnabled.w<0.5f){return false;}
    float2 viewport=uniforms.occlusionViewportBiasAndEnabled.xy;
    if(any(viewport<1.0f)){return false;}
    float3 root=record.rootAndPennaceousStart.xyz;
    float3 tip=record.tipAndCamber.xyz;
    float featherLength=distance(root,tip);
    float maximumWidth=record.widthsEnvelopeAndAsymmetry.y
        *(1.0f+abs(record.widthsEnvelopeAndAsymmetry.w));
    float radius=0.5f*featherLength+maximumWidth
        +abs(record.tipAndCamber.w)
        +abs(record.normalAndTransverseCamber.w)*maximumWidth
        +abs(record.lateralSweepAndReserved.x)
        +uniforms.occlusionBodyCenterAndPadding.w;
    float3 center=0.5f*(root+tip)
        +uniforms.occlusionBodyCenterAndPadding.xyz;
    float2 minimumPixel=viewport;
    float2 maximumPixel=float2(0.0f);
    float nearestDepth=1.0f;
    for(uint corner=0u;corner<8u;++corner){
        float3 sign=float3(
            (corner&1u)==0u?-1.0f:1.0f,
            (corner&2u)==0u?-1.0f:1.0f,
            (corner&4u)==0u?-1.0f:1.0f
        );
        float4 clip=uniforms.previousViewProjection
            *float4(center+sign*radius,1.0f);
        if(clip.w<=1.0e-6f){return false;}
        float3 ndc=clip.xyz/clip.w;
        if(ndc.z<=0.0f||ndc.z>=1.0f){return false;}
        float2 pixel=(ndc.xy*0.5f+0.5f)*viewport;
        minimumPixel=min(minimumPixel,pixel);
        maximumPixel=max(maximumPixel,pixel);
        nearestDepth=min(nearestDepth,ndc.z);
    }
    // Two output pixels absorb jitter, raster quantization, and subpixel body
    // motion. Bounds touching the image edge fail open because prior background
    // outside the viewport is unknown.
    minimumPixel-=2.0f;
    maximumPixel+=2.0f;
    if(any(minimumPixel<0.0f)||any(maximumPixel>=viewport)){return false;}
    float maximumExtent=max(
        maximumPixel.x-minimumPixel.x,
        maximumPixel.y-minimumPixel.y
    );
    uint level=uint(floor(log2(max(maximumExtent,1.0f))));
    level=min(level,previousDepth.get_num_mip_levels()-1u);
    float scale=exp2(float(level));
    uint2 first=uint2(floor(minimumPixel/scale));
    uint2 last=uint2(floor(maximumPixel/scale));
    uint2 levelSize=uint2(
        previousDepth.get_width(level),previousDepth.get_height(level)
    );
    first=min(first,levelSize-1u);
    last=min(last,levelSize-1u);
    if(any(last-first>2u)){return false;}
    float maximumDepth=0.0f;
    for(uint y=0u;y<3u;++y){
        for(uint x=0u;x<3u;++x){
            uint2 coordinate=first+uint2(x,y);
            if(any(coordinate>last)){continue;}
            maximumDepth=max(
                maximumDepth,previousDepth.read(coordinate,level).x
            );
        }
    }
    // Clear depth is one, so any prior background in the covered hierarchy
    // rejects the cull. The bias moves the occluder away from the camera.
    if(maximumDepth>=0.999999f){return false;}
    return maximumDepth+uniforms.occlusionViewportBiasAndEnabled.z
        <nearestDepth;
}

kernel void classifyCrowVentralBarbRecords(
    device const CrowVentralRachisCurveRecordGPU* records [[buffer(0)]],
    device uint* selected [[buffer(1)]],
    constant CrowVentralBarbVisibilityUniforms& uniforms [[buffer(2)]],
    texture2d<float,access::read> previousDepth [[texture(0)]],
    uint recordIndex [[thread_position_in_grid]]) {
    if(recordIndex>=uniforms.counts.x){return;}
    CrowVentralRachisCurveRecordGPU record=records[recordIndex];
    if(!crowVentralBarbRecordVisible(record,uniforms)){
        selected[recordIndex]=0u;
        return;
    }
    float projectedLength=crowVentralLODReferenceLength(record)
        *uniforms.selection.x;
    bool closeTier=projectedLength>=uniforms.barbuleSelection.w;
    bool barbules=projectedLength>=uniforms.barbuleSelection.x;
    bool occluded=crowVentralBarbRecordOccluded(
        record,uniforms,previousDepth
    );
    // 0 rejected; 1/2 visible/occluded aggregate; 3/4 close; 5/6 barbules.
    selected[recordIndex]=barbules?(occluded?6u:5u)
        :(closeTier?(occluded?4u:3u):(occluded?2u:1u));
}

kernel void scanCrowVentralBarbRecordVisibility(
    device const uint* selected [[buffer(0)]],
    device uint* offsets [[buffer(1)]],
    device uint* compactedCount [[buffer(2)]],
    constant CrowVentralBarbVisibilityUniforms& uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u){return;}
    uint runningWork=0u;
    uint retained=0u;
    uint frustumVisible=0u;
    uint occlusionCulled=0u;
    uint retainedBarbules=0u;
    uint frustumBarbules=0u;
    uint closeBarbWork=uint(uniforms.selection.z)*2u
        *uint(uniforms.selection.w);
    uint aggregateBarbWork=uniforms.counts.w*2u
        *uint(uniforms.selection.w);
    uint barbuleWork=uint(uniforms.selection.z)*2u
        *uint(uniforms.barbuleSelection.y)*uint(uniforms.barbuleSelection.z);
    for(uint recordIndex=0u;recordIndex<uniforms.counts.x;++recordIndex){
        offsets[recordIndex]=runningWork;
        uint classification=selected[recordIndex];
        bool visible=(classification&1u)!=0u;
        bool closeTier=classification>=3u;
        bool barbules=classification>=5u;
        retained+=visible?1u:0u;
        frustumVisible+=classification!=0u?1u:0u;
        occlusionCulled+=(classification!=0u&&!visible)?1u:0u;
        retainedBarbules+=classification==5u?1u:0u;
        frustumBarbules+=barbules?1u:0u;
        uint barbWork=closeTier?closeBarbWork:aggregateBarbWork;
        runningWork+=visible?(barbWork+(barbules?barbuleWork:0u)):0u;
    }
    compactedCount[0]=retained;
    compactedCount[1]=frustumVisible;
    compactedCount[2]=occlusionCulled;
    compactedCount[3]=uniforms.occlusionViewportBiasAndEnabled.w>=0.5f
        ?frustumVisible:0u;
    compactedCount[4]=retainedBarbules;
    compactedCount[5]=frustumBarbules;
    compactedCount[6]=runningWork;
    compactedCount[7]=0u;
}

kernel void emitCrowVentralBarbWork(
    device const uint* selected [[buffer(0)]],
    device const uint* offsets [[buffer(1)]],
    device CrowVentralBarbSegmentWorkGPU* work [[buffer(2)]],
    constant CrowVentralBarbVisibilityUniforms& uniforms [[buffer(3)]],
    uint recordIndex [[thread_position_in_grid]]) {
    if(recordIndex>=uniforms.counts.x){return;}
    uint classification=selected[recordIndex];
    if((classification&1u)==0u){return;}
    bool closeTier=classification>=3u;
    uint pairCount=closeTier?uint(uniforms.selection.z):uniforms.counts.w;
    uint intervalCount=uint(uniforms.selection.w);
    uint outputIndex=offsets[recordIndex];
    for(uint pairIndex=0u;pairIndex<pairCount;++pairIndex){
        for(uint sideIndex=0u;sideIndex<2u;++sideIndex){
            for(uint intervalIndex=0u;intervalIndex<intervalCount;++intervalIndex){
                CrowVentralBarbSegmentWorkGPU item;
                item.indices=uint4(
                    recordIndex,
                    pairIndex,
                    pairCount|(sideIndex<<16u),
                    intervalIndex|(intervalCount<<16u)
                );
                work[outputIndex++]=item;
            }
        }
    }
    if(classification==5u){
        uint barbulesPerBranch=uint(uniforms.barbuleSelection.y);
        uint branchCount=uint(uniforms.barbuleSelection.z);
        for(uint pairIndex=0u;pairIndex<pairCount;++pairIndex){
            for(uint sideIndex=0u;sideIndex<2u;++sideIndex){
                for(uint branchIndex=0u;branchIndex<branchCount;++branchIndex){
                    for(uint barbuleIndex=0u;
                        barbuleIndex<barbulesPerBranch;++barbuleIndex){
                        CrowVentralBarbSegmentWorkGPU item;
                        item.indices=uint4(
                            recordIndex,
                            pairIndex,
                            pairCount|(sideIndex<<16u),
                            0x80000000u|barbuleIndex
                                |(barbulesPerBranch<<16u)
                                |(branchIndex<<24u)
                        );
                        work[outputIndex++]=item;
                    }
                }
            }
        }
    }
}

kernel void prepareCrowVentralBarbIndirectWork(
    device const uint* compactedCount [[buffer(0)]],
    device CrowFeatherDrawArguments* drawArguments [[buffer(1)]],
    device CrowFeatherDispatchArguments* dispatchArguments [[buffer(2)]],
    constant CrowVentralBarbVisibilityUniforms& uniforms [[buffer(3)]],
    constant uint& threadsPerThreadgroup [[buffer(4)]],
    device CrowFeatherDispatchArguments* meshDispatchArguments [[buffer(5)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u){return;}
    uint vertexCount=compactedCount[6]*uniforms.counts.y;
    drawArguments[0].vertexCount=vertexCount;
    drawArguments[0].instanceCount=1u;
    drawArguments[0].vertexStart=0u;
    drawArguments[0].baseInstance=0u;
    dispatchArguments[0].threadgroupsPerGrid[0]=vertexCount==0u?0u:
        (vertexCount+threadsPerThreadgroup-1u)/threadsPerThreadgroup;
    dispatchArguments[0].threadgroupsPerGrid[1]=1u;
    dispatchArguments[0].threadgroupsPerGrid[2]=1u;
    uint meshWorkCount=compactedCount[6];
    uint meshGridWidth=min(meshWorkCount,4096u);
    meshDispatchArguments[0].threadgroupsPerGrid[0]=meshGridWidth;
    meshDispatchArguments[0].threadgroupsPerGrid[1]=meshWorkCount==0u?1u:
        (meshWorkCount+meshGridWidth-1u)/meshGridWidth;
    meshDispatchArguments[0].threadgroupsPerGrid[2]=1u;
}

// One compiled helper is shared by compute audit expansion and production
// vertex pulling. Prevent per-stage reassociation so both paths remain
// raster/AOV exact rather than merely visually close.
__attribute__((noinline)) CrowFeatherVertexGPU crowVentralBarbVertex(
    device const CrowVentralRachisCurveRecordGPU* records,
    device const CrowVentralBarbSegmentWorkGPU* work,
    constant CrowVentralBarbGeometryUniforms& uniforms,
    uint outputIndex) {
    uint verticesPerInterval=uniforms.counts.z;
    uint workIndex=outputIndex/verticesPerInterval;
    uint localVertex=outputIndex-workIndex*verticesPerInterval;
    CrowVentralBarbSegmentWorkGPU selected=work[workIndex];
    CrowVentralRachisCurveRecordGPU record=records[selected.indices.x];
    uint pairCount=selected.indices.z&0xffffu;
    uint sideIndex=(selected.indices.z>>16u)&1u;
    float side=sideIndex==0u?-1.0f:1.0f;
    uint intervalIndex=selected.indices.w&0xffffu;
    uint intervalCount=max(selected.indices.w>>16u,1u);
    float first=float(intervalIndex)/float(intervalCount);
    float second=float(intervalIndex+1u)/float(intervalCount);
    float3 start=crowVentralBarbPoint(
        record,selected.indices.y,pairCount,side,first
    );
    float3 end=crowVentralBarbPoint(
        record,selected.indices.y,pairCount,side,second
    );
    float startRadius=crowVentralBarbRadius(
        record,selected.indices.y,sideIndex,first
    );
    float endRadius=crowVentralBarbRadius(
        record,selected.indices.y,sideIndex,second
    );
    uint triangle=localVertex/3u;
    uint triangleCorner=localVertex%3u;
    uint radialIndex=triangle/2u;
    bool secondTriangle=(triangle&1u)!=0u;
    uint corner=secondTriangle
        ?uint3(0u,2u,3u)[triangleCorner]
        :uint3(0u,1u,2u)[triangleCorner];
    uint3 normalCorners=secondTriangle?uint3(0u,2u,3u):uint3(0u,1u,2u);
    float3 a=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.x
    );
    float3 b=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.y
    );
    float3 c=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.z
    );
    float3 localPosition=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,corner
    );
    float3 normal=safeNormalizeCrow(cross(b-a,c-a),float3(0,0,1));
    float material=record.edgeRippleAndMaterial.w;
    float3 color=float3(
        0.0080f*(1.0f+0.06f*material),
        0.0120f*(1.0f+0.04f*material),
        0.0200f*(1.0f+0.03f*material)
    );
    uint primitiveIdentifier=0x07100000u+selected.indices.x*8192u
        +selected.indices.y*64u+sideIndex*32u+intervalIndex*8u+triangle+1u;
    float curveT=(corner==2u||corner==3u)?second:first;
    float safePairCount=max(float(pairCount),1.0f);
    float spacing=0.77f/(safePairCount+1.0f);
    float attachmentVariation=crowVentralBarbVariation(
        record,selected.indices.y,sideIndex,0x9E3779B9u
    );
    float curvatureVariation=crowVentralBarbVariation(
        record,selected.indices.y,sideIndex,0x85EBCA6Bu
    );
    float localAxial=0.10f+spacing*float(selected.indices.y+1u)
        +0.24f*spacing*attachmentVariation;
    float localReach=min(
        0.94f,localAxial+0.030f+0.018f*localAxial
            +0.16f*spacing*curvatureVariation
    );
    float featherAxial=mix(
        mix(record.rootAndPennaceousStart.w,1.0f,localAxial),
        mix(record.rootAndPennaceousStart.w,1.0f,localReach),
        curveT
    );
    CrowFeatherVertexGPU result;
    result.position=float4(localPosition+uniforms.currentBodyCenter.xyz,1);
    result.previousPosition=float4(
        localPosition+uniforms.previousBodyCenter.xyz,1
    );
    result.normal=float4(normal,0);
    result.color=float4(color,0.14f);
    result.identity=uint4(
        0xffffffffu,primitiveIdentifier,3u,uniforms.counts.w
    );
    result.parameters=float4(
        featherAxial,side,0.031f*float(selected.indices.x%97u),1
    );
    return result;
}

__attribute__((noinline)) CrowFeatherVertexGPU crowVentralBarbuleVertex(
    device const CrowVentralRachisCurveRecordGPU* records,
    device const CrowVentralBarbSegmentWorkGPU* work,
    constant CrowVentralBarbGeometryUniforms& uniforms,
    uint outputIndex) {
    uint verticesPerInterval=uniforms.counts.z;
    uint workIndex=outputIndex/verticesPerInterval;
    uint localVertex=outputIndex-workIndex*verticesPerInterval;
    CrowVentralBarbSegmentWorkGPU selected=work[workIndex];
    CrowVentralRachisCurveRecordGPU record=records[selected.indices.x];
    uint pairCount=selected.indices.z&0xffffu;
    uint sideIndex=(selected.indices.z>>16u)&1u;
    uint barbuleIndex=selected.indices.w&0xffffu;
    uint barbuleCount=max((selected.indices.w>>16u)&0xffu,1u);
    uint branchIndex=(selected.indices.w>>24u)&1u;
    float3 start=crowVentralBarbulePoint(
        record,selected.indices.y,pairCount,sideIndex,
        barbuleIndex,barbuleCount,branchIndex,0.0f
    );
    float3 end=crowVentralBarbulePoint(
        record,selected.indices.y,pairCount,sideIndex,
        barbuleIndex,barbuleCount,branchIndex,1.0f
    );
    float startRadius=crowVentralBarbuleRadius(
        record,selected.indices.y,sideIndex,barbuleIndex,0.0f
    );
    float endRadius=crowVentralBarbuleRadius(
        record,selected.indices.y,sideIndex,barbuleIndex,1.0f
    );
    uint triangle=localVertex/3u;
    uint triangleCorner=localVertex%3u;
    uint radialIndex=triangle/2u;
    bool secondTriangle=(triangle&1u)!=0u;
    uint corner=secondTriangle
        ?uint3(0u,2u,3u)[triangleCorner]
        :uint3(0u,1u,2u)[triangleCorner];
    uint3 normalCorners=secondTriangle?uint3(0u,2u,3u):uint3(0u,1u,2u);
    float3 a=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.x
    );
    float3 b=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.y
    );
    float3 c=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,normalCorners.z
    );
    float3 localPosition=crowVentralRachisTubePoint(
        start,end,startRadius,endRadius,radialIndex,corner
    );
    float3 normal=safeNormalizeCrow(cross(b-a,c-a),float3(0,0,1));
    float material=record.edgeRippleAndMaterial.w;
    float localOcclusion=crowVentralBarbuleLocalOcclusion(
        barbuleIndex,barbuleCount,branchIndex
    );
    float3 color=localOcclusion*float3(
        0.0080f*(1.0f+0.06f*material),
        0.0120f*(1.0f+0.04f*material),
        0.0200f*(1.0f+0.03f*material)
    );
    uint primitiveIdentifier=0x09000000u+selected.indices.x*65536u
        +selected.indices.y*512u+sideIndex*256u+branchIndex*128u
        +barbuleIndex*16u+triangle+1u;
    float curveT=(corner==2u||corner==3u)?1.0f:0.0f;
    float2 coordinates=crowVentralBarbuleVaneCoordinates(
        record,selected.indices.y,pairCount,sideIndex,
        barbuleIndex,barbuleCount,branchIndex,curveT
    );
    CrowFeatherVertexGPU result;
    result.position=float4(localPosition+uniforms.currentBodyCenter.xyz,1);
    result.previousPosition=float4(
        localPosition+uniforms.previousBodyCenter.xyz,1
    );
    result.normal=float4(normal,0);
    result.color=float4(color,0.14f);
    result.identity=uint4(
        0xffffffffu,primitiveIdentifier,4u,uniforms.counts.w
    );
    result.parameters=float4(
        coordinates.x,coordinates.y,0.031f*float(selected.indices.x%97u),1
    );
    return result;
}

inline CrowFeatherVertexGPU crowVentralBarbProceduralVertex(
    device const CrowVentralRachisCurveRecordGPU* records,
    device const CrowVentralBarbSegmentWorkGPU* work,
    constant CrowVentralBarbGeometryUniforms& uniforms,
    uint outputIndex) {
    uint workIndex=outputIndex/uniforms.counts.z;
    return (work[workIndex].indices.w&0x80000000u)!=0u
        ?crowVentralBarbuleVertex(records,work,uniforms,outputIndex)
        :crowVentralBarbVertex(records,work,uniforms,outputIndex);
}

inline float3 crowVentralBarbProceduralTangent(
    device const CrowVentralRachisCurveRecordGPU* records,
    device const CrowVentralBarbSegmentWorkGPU* work,
    constant CrowVentralBarbGeometryUniforms& uniforms,
    uint outputIndex) {
    uint workIndex=outputIndex/uniforms.counts.z;
    CrowVentralBarbSegmentWorkGPU selected=work[workIndex];
    CrowVentralRachisCurveRecordGPU record=records[selected.indices.x];
    uint pairCount=selected.indices.z&0xffffu;
    uint sideIndex=(selected.indices.z>>16u)&1u;
    if((selected.indices.w&0x80000000u)!=0u){
        uint barbuleIndex=selected.indices.w&0xffffu;
        uint barbuleCount=max((selected.indices.w>>16u)&0xffu,1u);
        uint branchIndex=(selected.indices.w>>24u)&1u;
        float3 start=crowVentralBarbulePoint(
            record,selected.indices.y,pairCount,sideIndex,
            barbuleIndex,barbuleCount,branchIndex,0.0f
        );
        float3 end=crowVentralBarbulePoint(
            record,selected.indices.y,pairCount,sideIndex,
            barbuleIndex,barbuleCount,branchIndex,1.0f
        );
        return safeNormalizeCrow(end-start,float3(1.0f,0.0f,0.0f));
    }
    uint intervalIndex=selected.indices.w&0xffffu;
    uint intervalCount=max(selected.indices.w>>16u,1u);
    float first=float(intervalIndex)/float(intervalCount);
    float second=float(intervalIndex+1u)/float(intervalCount);
    float side=sideIndex==0u?-1.0f:1.0f;
    float3 start=crowVentralBarbPoint(
        record,selected.indices.y,pairCount,side,first
    );
    float3 end=crowVentralBarbPoint(
        record,selected.indices.y,pairCount,side,second
    );
    return safeNormalizeCrow(end-start,float3(1.0f,0.0f,0.0f));
}

struct CrowVentralCurveMeshVertex {
    float4 position [[position]];
    float4 previousClipPosition;
    float3 world;
    float4 albedoAndMaterial;
    float3 featherCoordinates;
    float3 resolvedCurveTangent;
};

struct CrowVentralCurvePrimitive {
    float3 normal [[flat]];
    uint4 identity [[flat]];
};

inline float4 crowSurfaceBiasedClipPosition(
    float4 clipPosition,uint featherClass);

using CrowVentralCurveMesh = metal::mesh<
    CrowVentralCurveMeshVertex,
    CrowVentralCurvePrimitive,
    8,
    8,
    metal::topology::triangle
>;

/// One compact interval work record owns one mesh threadgroup. Eight shared
/// ring vertices replace the 24-vertex triangle stream; flat normals and exact
/// identities remain per primitive so tube facets do not become smoothed.
[[mesh]] void crowVentralBarbAOVMesh(
    device const CrowVentralRachisCurveRecordGPU* records [[buffer(0)]],
    device const CrowVentralBarbSegmentWorkGPU* work [[buffer(1)]],
    constant CrowVentralBarbGeometryUniforms& geometry [[buffer(2)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(3)]],
    device const uint* compactedCount [[buffer(4)]],
    CrowVentralCurveMesh outputMesh,
    uint tid [[thread_index_in_threadgroup]],
    uint3 workPosition [[threadgroup_position_in_grid]]) {
    uint workCount=compactedCount[6];
    uint gridWidth=min(workCount,4096u);
    uint workIndex=workPosition.x+gridWidth*workPosition.y;
    if(workIndex>=workCount){
        if(tid==0u){outputMesh.set_primitive_count(0u);}
        return;
    }
    uint workVertexBase=workIndex*24u;
    if(tid<8u){
        uint radialIndex=tid&3u;
        bool atEnd=tid>=4u;
        uint representative=atEnd?radialIndex*6u+5u:radialIndex*6u;
        CrowFeatherVertexGPU source=crowVentralBarbProceduralVertex(
            records,work,geometry,workVertexBase+representative
        );
        CrowVentralCurveMeshVertex out;
        uint featherClass=source.identity.w&255u;
        out.position=crowSurfaceBiasedClipPosition(
            camera.viewProjection*source.position,featherClass
        );
        out.previousClipPosition=crowSurfaceBiasedClipPosition(
            camera.previousViewProjection*source.previousPosition,featherClass
        );
        out.world=source.position.xyz;
        out.albedoAndMaterial=source.color;
        out.featherCoordinates=source.parameters.xyz;
        out.resolvedCurveTangent=crowVentralBarbProceduralTangent(
            records,work,geometry,workVertexBase+representative
        );
        outputMesh.set_vertex(tid,out);

        uint triangle=tid;
        uint triangleRadial=triangle>>1u;
        uint triangleNext=(triangleRadial+1u)&3u;
        uint3 indices=(triangle&1u)==0u
            ?uint3(triangleRadial,triangleNext,4u+triangleNext)
            :uint3(triangleRadial,4u+triangleNext,4u+triangleRadial);
        outputMesh.set_index(3u*triangle,uchar(indices.x));
        outputMesh.set_index(3u*triangle+1u,uchar(indices.y));
        outputMesh.set_index(3u*triangle+2u,uchar(indices.z));

        CrowFeatherVertexGPU primitiveSource=crowVentralBarbProceduralVertex(
            records,work,geometry,workVertexBase+3u*triangle
        );
        CrowVentralCurvePrimitive primitive;
        primitive.normal=normalize(primitiveSource.normal.xyz);
        primitive.identity=primitiveSource.identity;
        outputMesh.set_primitive(tid,primitive);
    }
    if(tid==0u){outputMesh.set_primitive_count(8u);}
}

kernel void expandCrowVentralBarbCurves(
    device const CrowVentralRachisCurveRecordGPU* records [[buffer(0)]],
    device const CrowVentralBarbSegmentWorkGPU* work [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    constant CrowVentralBarbGeometryUniforms& uniforms [[buffer(3)]],
    uint outputIndex [[thread_position_in_grid]]) {
    uint outputCount=uniforms.counts.y*uniforms.counts.z;
    if(outputIndex>=outputCount){return;}
    output[outputIndex]=crowVentralBarbProceduralVertex(
        records,work,uniforms,outputIndex
    );
}

inline float4 quaternionConjugate(float4 q) { return float4(-q.xyz, q.w); }
inline float3 quaternionRotate(float4 q, float3 v) {
    float3 t = 2.0f * cross(q.xyz, v);
    return v + q.w * t + cross(q.xyz, t);
}

inline float3 quaternionUnrotate(float4 q, float3 v) {
    return quaternionRotate(quaternionConjugate(q), v);
}

inline float sdEllipsoid(float3 p, float3 radii) {
    float k0 = length(p / radii);
    float k1 = length(p / (radii * radii));
    return k1 > 1.0e-12f ? k0 * (k0 - 1.0f) / k1 : -min(radii.x, min(radii.y, radii.z));
}

inline float sdWing(float3 world, float4 root, float4 chordAxis, float4 spanAxis,
                    float4 normalAxis, constant VisualizationUniforms& u) {
    float3 relative = world - root.xyz;
    float3 local = float3(dot(relative, chordAxis.xyz), dot(relative, spanAxis.xyz), dot(relative, normalAxis.xyz));
    float t = clamp(local.y / max(u.wingGeometry0.x, 1.0e-6f), 0.0f, 1.0f);
    float chord = mix(u.wingGeometry0.y, u.wingGeometry0.z, t);
    float center = -u.wingGeometry1.x * t;
    float3 q = float3(
        abs(local.x - center) - 0.5f * chord,
        max(-local.y, local.y - u.wingGeometry0.x),
        abs(local.z) - 0.5f * u.wingGeometry0.w
    );
    return length(max(q, float3(0))) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

inline float sdTail(float3 local, constant VisualizationUniforms& u) {
    float x = -(local.x + u.bodyRadiiAndTail.x);
    float t = clamp(x / max(u.bodyRadiiAndTail.w, 1.0e-6f), 0.0f, 1.0f);
    float halfWidth = mix(0.35f * u.wingGeometry1.y, u.wingGeometry1.y, t);
    float3 q = float3(
        max(-x, x - u.bodyRadiiAndTail.w),
        abs(local.y) - halfWidth,
        abs(local.z + 0.15f * u.bodyRadiiAndTail.z) - 0.5f * u.wingGeometry1.z
    );
    return length(max(q, float3(0))) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

inline float birdDistance(float3 world, constant VisualizationUniforms& u) {
    float3 local = quaternionUnrotate(u.orientation, world - u.bodyPosition.xyz);
    float distance = sdEllipsoid(local, u.bodyRadiiAndTail.xyz);
    distance = min(distance, sdTail(local, u));
    distance = min(distance, sdWing(world, u.leftRoot, u.leftChord, u.leftSpan, u.leftNormal, u));
    distance = min(distance, sdWing(world, u.rightRoot, u.rightChord, u.rightSpan, u.rightNormal, u));
    return distance;
}

inline float3 gridCoordinate(float3 world, constant VisualizationUniforms& u) {
    return (world - u.originAndCellSize.xyz) / u.originAndCellSize.w - 0.5f;
}

inline bool sampleInside(float3 g, uint3 size) {
    return all(g >= float3(0)) && all(g <= float3(size - 1u));
}

inline float sampleScalar(device const float* values, float3 g, uint3 size) {
    float3 clamped = clamp(g, float3(0), float3(size - 1u));
    uint3 a = uint3(floor(clamped));
    uint3 b = min(a + 1u, size - 1u);
    float3 t = fract(clamped);
    float c000 = values[flatten(uint3(a.x, a.y, a.z), size)];
    float c100 = values[flatten(uint3(b.x, a.y, a.z), size)];
    float c010 = values[flatten(uint3(a.x, b.y, a.z), size)];
    float c110 = values[flatten(uint3(b.x, b.y, a.z), size)];
    float c001 = values[flatten(uint3(a.x, a.y, b.z), size)];
    float c101 = values[flatten(uint3(b.x, a.y, b.z), size)];
    float c011 = values[flatten(uint3(a.x, b.y, b.z), size)];
    float c111 = values[flatten(uint3(b.x, b.y, b.z), size)];
    return mix(mix(mix(c000, c100, t.x), mix(c010, c110, t.x), t.y),
               mix(mix(c001, c101, t.x), mix(c011, c111, t.x), t.y), t.z);
}

inline float3 sampleVector(device const float4* values, float3 g, uint3 size) {
    float3 clamped = clamp(g, float3(0), float3(size - 1u));
    uint3 a = uint3(floor(clamped));
    uint3 b = min(a + 1u, size - 1u);
    float3 t = fract(clamped);
    float3 c000 = values[flatten(uint3(a.x, a.y, a.z), size)].xyz;
    float3 c100 = values[flatten(uint3(b.x, a.y, a.z), size)].xyz;
    float3 c010 = values[flatten(uint3(a.x, b.y, a.z), size)].xyz;
    float3 c110 = values[flatten(uint3(b.x, b.y, a.z), size)].xyz;
    float3 c001 = values[flatten(uint3(a.x, a.y, b.z), size)].xyz;
    float3 c101 = values[flatten(uint3(b.x, a.y, b.z), size)].xyz;
    float3 c011 = values[flatten(uint3(a.x, b.y, b.z), size)].xyz;
    float3 c111 = values[flatten(uint3(b.x, b.y, b.z), size)].xyz;
    return mix(mix(mix(c000, c100, t.x), mix(c010, c110, t.x), t.y),
               mix(mix(c001, c101, t.x), mix(c011, c111, t.x), t.y), t.z);
}

inline float3 physicalVelocity(device const float4* velocity, float3 g,
                               constant VisualizationUniforms& u) {
    return sampleVector(velocity, g, u.grid.xyz) * u.scalesAndRanges.x;
}

inline float3 vorticityAt(device const float4* velocity, float3 g,
                          constant VisualizationUniforms& u) {
    float inv = 0.5f * u.scalesAndRanges.x / u.originAndCellSize.w;
    float3 dx = (sampleVector(velocity, g + float3(1,0,0), u.grid.xyz)
               - sampleVector(velocity, g - float3(1,0,0), u.grid.xyz)) * inv;
    float3 dy = (sampleVector(velocity, g + float3(0,1,0), u.grid.xyz)
               - sampleVector(velocity, g - float3(0,1,0), u.grid.xyz)) * inv;
    float3 dz = (sampleVector(velocity, g + float3(0,0,1), u.grid.xyz)
               - sampleVector(velocity, g - float3(0,0,1), u.grid.xyz)) * inv;
    return float3(dy.z - dz.y, dz.x - dx.z, dx.y - dy.x);
}

inline float3 sequentialMap(float t) {
    t = clamp(t, 0.0f, 1.0f);
    return clamp(float3(0.18f + 1.1f*t - 0.35f*t*t,
                        0.03f + 1.55f*t - 0.75f*t*t,
                        0.34f + 0.85f*t - 1.0f*t*t), 0.0f, 1.0f);
}

inline float3 divergingMap(float t) {
    t = clamp(t, -1.0f, 1.0f);
    float3 low = float3(0.08f, 0.28f, 0.78f);
    float3 center = float3(0.94f);
    float3 high = float3(0.86f, 0.20f, 0.08f);
    return t < 0 ? mix(center, low, -t) : mix(center, high, t);
}

kernel void samplePressureSurface(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    device const SurfaceVertex* input [[buffer(2)]],
    device ColoredVertex* output [[buffer(3)]],
    device atomic_uint* maximumPressureBits [[buffer(4)]],
    constant VisualizationUniforms& u [[buffer(5)]],
    uint gid [[thread_position_in_grid]]) {
    (void)velocity;
    SurfaceVertex surface = input[gid];
    float3 world = surface.position.xyz + surface.normal.xyz
        * u.scalesAndRanges.z * u.originAndCellSize.w;
    float rho = sampleScalar(density, gridCoordinate(world, u), u.grid.xyz);
    float pressure = (1.0f / 3.0f) * (rho - 1.0f) * u.scalesAndRanges.y;
    float displayed = ((u.flags.y & 4u) != 0u && u.displayOptions.x > 1.0e-8f)
        ? pressure / u.displayOptions.x : pressure;
    float magnitude = abs(displayed);
    atomic_fetch_max_explicit(maximumPressureBits, as_type<uint>(magnitude), memory_order_relaxed);
    uint bin = min(uint(255.0f * magnitude / u.scalesAndRanges.w), 255u);
    atomic_fetch_add_explicit(maximumPressureBits + 1u + bin, 1u, memory_order_relaxed);
    output[gid].position = surface.position;
    output[gid].normal = surface.normal;
    output[gid].color = float4(divergingMap(displayed / u.scalesAndRanges.w), 1);
    output[gid].parameters = float4(0);
}

kernel void renderFlowSlice(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    constant VisualizationUniforms& u [[buffer(2)]],
    device SliceProbeOutput* probe [[buffer(3)]],
    texture2d<float, access::write> output [[texture(0)]],
    uint2 pixel [[thread_position_in_grid]]) {
    (void)density;
    if (any(pixel >= uint2(output.get_width(), output.get_height()))) return;
    float2 uv = (float2(pixel) + 0.5f) / float2(output.get_width(), output.get_height());
    float3 world = u.sliceCenterAndOpacity.xyz
        + (2.0f * uv.x - 1.0f) * u.sliceUAndHalfWidth.w * u.sliceUAndHalfWidth.xyz
        + (2.0f * uv.y - 1.0f) * u.sliceVAndHalfHeight.w * u.sliceVAndHalfHeight.xyz;
    float3 g = gridCoordinate(world, u);
    if (!sampleInside(g, u.grid.xyz) || birdDistance(world, u) <= u.originAndCellSize.w) {
        output.write(float4(0), pixel);
        return;
    }
    float3 value = physicalVelocity(velocity, g, u);
    float3 curl = vorticityAt(velocity, g, u);
    float scalar;
    bool signedField = u.flags.x == 1u;
    if (u.flags.x == 0u) scalar = length(value);
    else if (signedField) scalar = dot(value, u.sliceNormalAndRange.xyz);
    else scalar = length(curl);
    float3 color = signedField
        ? divergingMap(scalar / u.sliceNormalAndRange.w)
        : sequentialMap(scalar / u.sliceNormalAndRange.w);
    if ((u.flags.y & 2u) != 0u) {
        float2 glyphGrid = float2(24.0f, 24.0f);
        float2 glyphCell = floor(uv * glyphGrid);
        float2 glyphUV = (glyphCell + 0.5f) / glyphGrid;
        float3 glyphWorld = u.sliceCenterAndOpacity.xyz
            + (2.0f * glyphUV.x - 1.0f) * u.sliceUAndHalfWidth.w * u.sliceUAndHalfWidth.xyz
            + (2.0f * glyphUV.y - 1.0f) * u.sliceVAndHalfHeight.w * u.sliceVAndHalfHeight.xyz;
        float3 glyphVelocity = physicalVelocity(velocity, gridCoordinate(glyphWorld, u), u);
        float2 direction = float2(dot(glyphVelocity, u.sliceUAndHalfWidth.xyz),
                                  dot(glyphVelocity, u.sliceVAndHalfHeight.xyz));
        direction /= max(length(direction), 1.0e-8f);
        float2 local = fract(uv * glyphGrid) - 0.5f;
        float along = dot(local, direction);
        float across = abs(local.x * direction.y - local.y * direction.x);
        bool shaft = along > -0.3f && along < 0.25f && across < 0.035f;
        float2 tip = local - 0.25f * direction;
        bool head = dot(tip, direction) < 0.0f && dot(tip, direction) > -0.18f
            && abs(tip.x * direction.y - tip.y * direction.x)
                < -dot(tip, direction) * 0.65f;
        if (shaft || head) color = mix(color, float3(1), 0.82f);
    }
    uint2 probePixel = min(
        uint2(u.probeUVAndPadding.xy * float2(output.get_width(), output.get_height())),
        uint2(output.get_width() - 1u, output.get_height() - 1u)
    );
    if (all(pixel == probePixel)) {
        probe[0].worldAndScalar = float4(world, scalar);
        probe[0].velocity = float4(value, length(value));
        probe[0].vorticity = float4(curl, length(curl));
    }
    output.write(float4(color, u.sliceCenterAndOpacity.w), pixel);
}

kernel void deriveFlowDiagnostics(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    device float4* vorticity [[buffer(2)]],
    device float* qCriterion [[buffer(3)]],
    device uchar* valid [[buffer(4)]],
    constant VisualizationUniforms& u [[buffer(5)]],
    uint gid [[thread_position_in_grid]]) {
    (void)density;
    if (gid >= u.grid.w) return;
    uint3 cell = unflatten(gid, u.grid.xyz);
    bool boundary = any(cell == 0u) || any(cell + 1u >= u.grid.xyz);
    float3 world = u.originAndCellSize.xyz + (float3(cell) + 0.5f) * u.originAndCellSize.w;
    if (boundary || birdDistance(world, u) <= u.originAndCellSize.w) {
        vorticity[gid] = float4(0);
        qCriterion[gid] = 0;
        valid[gid] = uchar(0);
        return;
    }
    float scale = 0.5f * u.scalesAndRanges.x / u.originAndCellSize.w;
    float3 dx = (velocity[flatten(cell + uint3(1,0,0), u.grid.xyz)].xyz
               - velocity[flatten(cell - uint3(1,0,0), u.grid.xyz)].xyz) * scale;
    float3 dy = (velocity[flatten(cell + uint3(0,1,0), u.grid.xyz)].xyz
               - velocity[flatten(cell - uint3(0,1,0), u.grid.xyz)].xyz) * scale;
    float3 dz = (velocity[flatten(cell + uint3(0,0,1), u.grid.xyz)].xyz
               - velocity[flatten(cell - uint3(0,0,1), u.grid.xyz)].xyz) * scale;
    float3 curl = float3(dy.z - dz.y, dz.x - dx.z, dx.y - dy.x);
    float traceSquare = dx.x*dx.x + dy.y*dy.y + dz.z*dz.z
        + 2.0f * (dx.y*dy.x + dx.z*dz.x + dy.z*dz.y);
    vorticity[gid] = float4(curl, length(curl));
    qCriterion[gid] = -0.5f * traceSquare;
    valid[gid] = uchar(1);
}

kernel void summarizeQCriterion(
    device const float* qCriterion [[buffer(0)]],
    device const uchar* valid [[buffer(1)]],
    device atomic_uint* statistics [[buffer(2)]],
    constant VisualizationUniforms& u [[buffer(3)]],
    uint gid [[thread_position_in_grid]]) {
    if (gid >= u.grid.w || valid[gid] == 0 || qCriterion[gid] <= 0.0f) return;
    float q = qCriterion[gid];
    atomic_fetch_max_explicit(statistics, as_type<uint>(q), memory_order_relaxed);
    uint bin = min(uint(255.0f * q / u.displayOptions.w), 255u);
    atomic_fetch_add_explicit(statistics + 1u + bin, 1u, memory_order_relaxed);
}

inline float3 tracerSeed(uint gid, constant VisualizationUniforms& u) {
    uint count = max(u.flags.z, 1u);
    uint halfCount = max(count / 2u, 1u);
    float3 domain = float3(u.grid.xyz) * u.originAndCellSize.w;
    if (gid < halfCount) {
        uint side = uint(ceil(sqrt(float(halfCount))));
        float y = (float(gid % side) + 0.5f) / float(side);
        float z = (float(gid / side) + 0.5f) / float(side);
        return u.originAndCellSize.xyz + float3(0.88f*domain.x, (0.2f+0.6f*y)*domain.y, (0.2f+0.6f*z)*domain.z);
    }
    uint local = gid - halfCount;
    bool left = (local & 1u) == 0u;
    float fraction = float(local / 2u) / max(float((count-halfCount)/2u), 1.0f);
    float3 root = left ? u.leftRoot.xyz : u.rightRoot.xyz;
    float3 span = left ? u.leftSpan.xyz : u.rightSpan.xyz;
    float3 normal = left ? u.leftNormal.xyz : u.rightNormal.xyz;
    return root + span * u.wingGeometry0.x * mix(0.65f, 1.02f, fraction)
        + normal * u.originAndCellSize.w * 2.0f;
}

kernel void advectTracerRibbons(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    device TracerState* states [[buffer(2)]],
    device float4* history [[buffer(3)]],
    constant VisualizationUniforms& u [[buffer(4)]],
    uint gid [[thread_position_in_grid]]) {
    (void)density;
    if (gid >= u.flags.z) return;
    uint historyLength = u.flags.w;
    TracerState state = states[gid];
    float dt = u.tracerAndIso.x;
    bool reset = (u.flags.y & 1u) != 0u || state.positionAndAge.w <= 0.0f || dt <= 0.0f;
    float3 position = reset ? tracerSeed(gid, u) : state.positionAndAge.xyz;
    float3 g = gridCoordinate(position, u);
    float3 speed = physicalVelocity(velocity, g, u);
    uint substeps = uint(ceil(length(speed) * dt / max(0.5f*u.originAndCellSize.w, 1.0e-8f)));
    if (substeps > 8u || !sampleInside(g, u.grid.xyz)) reset = true;
    if (reset) {
        position = tracerSeed(gid, u);
        speed = physicalVelocity(velocity, gridCoordinate(position, u), u);
        for (uint i = 0; i < historyLength; ++i) history[gid*historyLength+i] = float4(position, 0);
    } else {
        substeps = max(substeps, 1u);
        float h = dt / float(substeps);
        for (uint step = 0; step < substeps; ++step) {
            float3 k1 = physicalVelocity(velocity, gridCoordinate(position, u), u);
            float3 midpoint = position + 0.5f*h*k1;
            float3 k2 = physicalVelocity(velocity, gridCoordinate(midpoint, u), u);
            position += h*k2;
        }
        if (!sampleInside(gridCoordinate(position, u), u.grid.xyz)
            || birdDistance(position, u) <= u.originAndCellSize.w) {
            position = tracerSeed(gid, u);
            for (uint i = 0; i < historyLength; ++i) history[gid*historyLength+i] = float4(position, 0);
        } else {
            for (uint i = historyLength - 1u; i > 0u; --i)
                history[gid*historyLength+i] = history[gid*historyLength+i-1u];
            float colorValue = (u.flags.y & 8u) != 0u
                ? length(vorticityAt(velocity, gridCoordinate(position, u), u))
                : length(speed);
            history[gid*historyLength] = float4(position, colorValue);
        }
    }
    states[gid].positionAndAge = float4(position, state.positionAndAge.w + dt + 1.0e-6f);
    states[gid].velocityAndSpeed = float4(speed, length(speed));
}

constant ushort3 CUBE_CORNERS[8] = {
    ushort3(0,0,0), ushort3(1,0,0), ushort3(1,1,0), ushort3(0,1,0),
    ushort3(0,0,1), ushort3(1,0,1), ushort3(1,1,1), ushort3(0,1,1)
};
constant ushort2 CUBE_EDGES[12] = {
    ushort2(0,1), ushort2(1,2), ushort2(2,3), ushort2(3,0),
    ushort2(4,5), ushort2(5,6), ushort2(6,7), ushort2(7,4),
    ushort2(0,4), ushort2(1,5), ushort2(2,6), ushort2(3,7)
};

inline uint cubeCellCount(uint3 grid) { return (grid.x-1u)*(grid.y-1u)*(grid.z-1u); }
inline uint3 cubePosition(uint gid, uint3 grid) {
    uint3 size = grid - 1u;
    uint xy = size.x * size.y;
    uint z = gid / xy;
    uint r = gid - z*xy;
    uint y = r / size.x;
    return uint3(r-y*size.x, y, z);
}
inline uint3 cornerOffset(uint c) { return uint3(CUBE_CORNERS[c]); }

kernel void classifyQCriterionCubes(
    device const float* q [[buffer(0)]],
    device const uchar* valid [[buffer(1)]],
    device uint* triangleCounts [[buffer(2)]],
    constant VisualizationUniforms& u [[buffer(3)]],
    device const char* triangleTable [[buffer(4)]],
    uint gid [[thread_position_in_grid]]) {
    if (gid >= cubeCellCount(u.grid.xyz)) return;
    uint3 base = cubePosition(gid, u.grid.xyz);
    float values[8];
    for (uint c=0;c<8;++c) {
        uint index=flatten(base+cornerOffset(c),u.grid.xyz);
        if (valid[index]==0) { triangleCounts[gid]=0; return; }
        values[c]=q[index]-u.tracerAndIso.y;
    }
    uint mask=0u;
    for(uint c=0;c<8;++c)if(values[c]>0.0f)mask|=1u<<c;
    uint entryCount=0u;
    while(entryCount<16u&&triangleTable[mask*16u+entryCount]>=0)++entryCount;
    triangleCounts[gid]=entryCount/3u;
}

kernel void scanTriangleBlocks(
    device const uint* counts [[buffer(0)]],
    device uint* offsets [[buffer(1)]],
    device uint* blockSums [[buffer(2)]],
    constant uint& count [[buffer(3)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint group [[threadgroup_position_in_grid]]) {
    threadgroup uint scratch[256];
    uint own = gid < count ? counts[gid] : 0u;
    scratch[tid]=own;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for(uint stride=1u;stride<256u;stride<<=1u){
        uint add=tid>=stride?scratch[tid-stride]:0u;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        scratch[tid]+=add;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if(gid<count) offsets[gid]=scratch[tid]-own;
    if(tid==255u) blockSums[group]=scratch[tid];
}

kernel void scanBlockSums(
    device const uint* blockSums [[buffer(0)]],
    device uint* blockOffsets [[buffer(1)]],
    constant uint& blockCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u)return;
    uint sum=0;
    for(uint i=0;i<blockCount;++i){blockOffsets[i]=sum;sum+=blockSums[i];}
}

kernel void addTriangleBlockOffsets(
    device uint* offsets [[buffer(0)]],
    device const uint* blockOffsets [[buffer(1)]],
    constant uint& count [[buffer(2)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid<count) offsets[gid]+=blockOffsets[gid/256u];
}

struct DrawPrimitivesIndirectArguments {
    uint vertexCount; uint instanceCount; uint vertexStart; uint baseInstance;
};

kernel void prepareQCriterionIndirectDraw(
    device const uint* counts [[buffer(0)]],
    device const uint* offsets [[buffer(1)]],
    device DrawPrimitivesIndirectArguments* arguments [[buffer(2)]],
    device uint* overflow [[buffer(3)]],
    constant uint2& countAndCapacity [[buffer(4)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u)return;
    uint count=countAndCapacity.x;
    uint total=count==0u?0u:offsets[count-1u]+counts[count-1u];
    bool exceeded=total>countAndCapacity.y;
    overflow[0]=exceeded?1u:0u;
    arguments[0].vertexCount=exceeded?0u:total*3u;
    arguments[0].instanceCount=1u;
    arguments[0].vertexStart=0u;
    arguments[0].baseInstance=0u;
}

inline float3 qGradientAt(
    device const float* q,
    uint3 cell,
    constant VisualizationUniforms& u
) {
    int3 center=int3(cell);
    int3 maximum=int3(u.grid.xyz)-1;
    int3 lowerX=max(center-int3(1,0,0),int3(0));
    int3 upperX=min(center+int3(1,0,0),maximum);
    int3 lowerY=max(center-int3(0,1,0),int3(0));
    int3 upperY=min(center+int3(0,1,0),maximum);
    int3 lowerZ=max(center-int3(0,0,1),int3(0));
    int3 upperZ=min(center+int3(0,0,1),maximum);
    float dx=max(float(upperX.x-lowerX.x)*u.originAndCellSize.w,1.0e-12f);
    float dy=max(float(upperY.y-lowerY.y)*u.originAndCellSize.w,1.0e-12f);
    float dz=max(float(upperZ.z-lowerZ.z)*u.originAndCellSize.w,1.0e-12f);
    return float3(
        (q[flatten(uint3(upperX),u.grid.xyz)]-q[flatten(uint3(lowerX),u.grid.xyz)])/dx,
        (q[flatten(uint3(upperY),u.grid.xyz)]-q[flatten(uint3(lowerY),u.grid.xyz)])/dy,
        (q[flatten(uint3(upperZ),u.grid.xyz)]-q[flatten(uint3(lowerZ),u.grid.xyz)])/dz
    );
}

kernel void emitQCriterionCubes(
    device const float* q [[buffer(0)]],
    device const uchar* valid [[buffer(1)]],
    device const uint* counts [[buffer(2)]],
    device const uint* offsets [[buffer(3)]],
    device IsoVertex* output [[buffer(4)]],
    constant VisualizationUniforms& u [[buffer(5)]],
    device const float4* vorticity [[buffer(6)]],
    device const char* triangleTable [[buffer(7)]],
    uint gid [[thread_position_in_grid]]) {
    (void)valid;
    if(gid>=cubeCellCount(u.grid.xyz)||counts[gid]==0u)return;
    if(offsets[gid]+counts[gid]>uint(u.tracerAndIso.w))return;
    uint3 base=cubePosition(gid,u.grid.xyz);
    float values[8];float3 points[8];float3 gradients[8];float omega[8];
    uint mask=0u;
    for(uint c=0;c<8;++c){
        uint3 cell=base+cornerOffset(c);uint index=flatten(cell,u.grid.xyz);
        values[c]=q[index]-u.tracerAndIso.y;
        points[c]=u.originAndCellSize.xyz+(float3(cell)+0.5f)*u.originAndCellSize.w;
        gradients[c]=qGradientAt(q,cell,u);omega[c]=vorticity[index].w;
        if(values[c]>0.0f)mask|=1u<<c;
    }
    uint triangle=offsets[gid];
    for(uint localTriangle=0u;localTriangle<counts[gid];++localTriangle){
        uint baseVertex=(triangle+localTriangle)*3u;
        for(uint vertexIndex=0u;vertexIndex<3u;++vertexIndex){
            int edgeIndex=int(triangleTable[mask*16u+localTriangle*3u+vertexIndex]);
            ushort2 edge=CUBE_EDGES[uint(edgeIndex)];
            uint a=edge.x,b=edge.y;
            float fraction=clamp(values[a]/(values[a]-values[b]),0.0f,1.0f);
            float3 position=mix(points[a],points[b],fraction);
            float3 normal=normalize(mix(gradients[a],gradients[b],fraction)+float3(1.0e-20f));
            float omegaValue=mix(omega[a],omega[b],fraction);
            output[baseVertex+vertexIndex]={float4(position,1),float4(normal,omegaValue)};
        }
    }
}

vertex RasterVertex coloredSurfaceVertex(
    device const ColoredVertex* vertices [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    ColoredVertex source=vertices[vid]; RasterVertex out;
    out.position=camera.viewProjection*source.position;out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);out.color=source.color;
    out.uv=source.parameters.xy;return out;
}

vertex RasterVertex crowFeatherVertex(
    device const CrowFeatherVertexGPU* vertices [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    CrowFeatherVertexGPU source=vertices[vid];RasterVertex out;
    out.position=camera.viewProjection*source.position;
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.color=source.color;
    out.uv=source.parameters.xy;
    return out;
}

// Surface-bound live coverts are anatomical decals over the closed scaffold.
// Bias depth only, never clip X/Y, so they remain visible without creating a
// second projected silhouette at grazing camera angles.
inline float4 crowSurfaceBiasedClipPosition(float4 clipPosition,uint featherClass){
    if(crowIsLiveCovert(featherClass)){
        clipPosition.z-=2.0e-5f*clipPosition.w;
    }else if(featherClass==16u){
        // The folded wing-tail lobe is a deep optical backing, not an exposed
        // surface. Let every nearly coincident remex/covert sample win depth
        // while the lobe remains available only in an actual image-space gap.
        clipPosition.z+=2.0e-4f*clipPosition.w;
    }
    return clipPosition;
}

// Retained barb ribbons sit only a fraction of a millimetre above the owning
// vane and can quantize to the same depth sample. At close-detail LOD, let
// rectrix microstructure own that coincident sample without moving any
// world-space vertex or altering the tail silhouette.
inline float4 crowRectrixDetailBiasedClipPosition(
    float4 clipPosition,uint featherClass,float detailKind){
    clipPosition=crowSurfaceBiasedClipPosition(clipPosition,featherClass);
    if(featherClass==3u&&detailKind>1.5f){
        clipPosition.z-=2.0e-5f*clipPosition.w;
    }
    return clipPosition;
}

inline uint2 crowBodyVaneGridIndex(
    uint vertexIndex,
    constant CrowBodyVaneGeometryUniforms& geometry) {
    uint cell=vertexIndex/6u;
    uint2 corner;
    switch(vertexIndex%6u){
        case 0u: corner=uint2(0u,0u); break;
        case 1u: corner=uint2(0u,1u); break;
        case 2u: corner=uint2(1u,1u); break;
        case 3u: corner=uint2(0u,0u); break;
        case 4u: corner=uint2(1u,1u); break;
        default: corner=uint2(1u,0u); break;
    }
    return uint2(cell/geometry.counts.y,cell%geometry.counts.y)+corner;
}

inline uint2 crowBodyVaneTopologySections(uint topologyIndex) {
    switch(topologyIndex){
        case 0u: return uint2(3u,1u);
        case 1u: return uint2(4u,1u);
        case 2u: return uint2(6u,5u);
        case 3u: return uint2(8u,5u);
        case 4u: return uint2(10u,5u);
        case 5u: return uint2(12u,5u);
        case 6u: return uint2(16u,7u);
        case 7u: return uint2(7u,3u);
        case 8u: return uint2(11u,5u);
        case 9u: return uint2(8u,3u);
        default: return uint2(6u,3u);
    }
}

inline uint crowBodyVaneTopologyIndex(
    CrowBodyVaneMorphologyGPU record,
    constant CrowBodyVaneSelectionUniforms& selection) {
    float projectedPixelsPerMeter=selection.selection.x;
    bool ventral=(record.identity.x&0xff000000u)==0x03000000u;
    bool femoral=(record.identity.x&0xff000000u)==0x04000000u;
    bool crural=(record.identity.x&0xff000000u)==0x05000000u;
    bool throatBridge=(record.identity.x&0xff000000u)==0x06000000u;
    bool cranial=(record.identity.x&0xff000000u)==0x07000000u;
    if(cranial){
        if((selection.counts.w&8u)==0u
            ||projectedPixelsPerMeter<1400.0f){
            return 0xffffffffu;
        }
        float projectedLength=max(0.0f,record.morphology.y
            *projectedPixelsPerMeter);
        if(projectedLength>=480.0f){return 6u;}
        if(projectedLength>=120.0f){return 4u;}
        if(projectedLength>=24.0f){return 10u;}
        return 0u;
    }
    if(femoral||crural){
        uint familyBit=femoral?1u:2u;
        if((selection.counts.w&familyBit)==0u
            ||projectedPixelsPerMeter<1400.0f){
            return 0xffffffffu;
        }
        float projectedLength=max(0.0f,record.morphology.y
            *projectedPixelsPerMeter);
        if(projectedLength>=480.0f){return 6u;}
        if(projectedLength>=120.0f){return crural?5u:8u;}
        if(projectedLength>=24.0f){return crural?9u:7u;}
        return 1u;
    }
    if(throatBridge){
        if((selection.counts.w&4u)==0u
            ||projectedPixelsPerMeter<1400.0f){
            return 0xffffffffu;
        }
        float projectedLength=max(0.0f,record.morphology.y
            *projectedPixelsPerMeter);
        if(projectedLength>=480.0f){return 6u;}
        if(projectedLength>=120.0f){return 8u;}
        if(projectedLength>=24.0f){return 7u;}
        return 1u;
    }
    if(ventral){
        if(projectedPixelsPerMeter<1400.0f){return 0xffffffffu;}
        float projectedLength=max(0.0f,record.morphology.y
            *projectedPixelsPerMeter);
        if(projectedLength>=480.0f){return 6u;}
        if(projectedLength>=120.0f){return 8u;}
        if(projectedLength>=24.0f){return 7u;}
        return 1u;
    }
    uint region=uint(record.morphology.y);
    uint row=uint(record.morphology.z);
    uint column=uint(record.morphology.w);
    bool active=projectedPixelsPerMeter>=1400.0f
        ||(projectedPixelsPerMeter>=900.0f
            ?((row+column)%2u==0u)
            :(region==0u?column%2u==0u
                :(row%2u==0u&&column%2u==0u)));
    if(!active){return 0xffffffffu;}
    float lengthMeters=length(
        record.tipAndMaximumWidth.xyz-record.rootAndRootWidth.xyz
    );
    float projectedLength=max(0.0f,lengthMeters*projectedPixelsPerMeter);
    bool cervical=region==0u;
    if(projectedLength>=480.0f){return 6u;}
    if(projectedLength>=120.0f){return cervical?4u:5u;}
    if(projectedLength>=24.0f){return cervical?2u:3u;}
    return cervical?0u:1u;
}

kernel void classifyCrowBodyVaneRecords(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device uint* topologyIndices [[buffer(1)]],
    constant CrowBodyVaneSelectionUniforms& selection [[buffer(2)]],
    uint index [[thread_position_in_grid]]) {
    if(index>=selection.counts.x){return;}
    topologyIndices[index]=crowBodyVaneTopologyIndex(records[index],selection);
}

kernel void scanCrowBodyVaneRecords(
    device const uint* topologyIndices [[buffer(0)]],
    device uint* topologyOffsets [[buffer(1)]],
    device uint* topologyCounts [[buffer(2)]],
    constant CrowBodyVaneSelectionUniforms& selection [[buffer(3)]],
    uint index [[thread_position_in_grid]]) {
    if(index>0u){return;}
    uint counts[11]={0u,0u,0u,0u,0u,0u,0u,0u,0u,0u,0u};
    for(uint recordIndex=0u;recordIndex<selection.counts.x;++recordIndex){
        uint topologyIndex=topologyIndices[recordIndex];
        if(topologyIndex<11u){
            topologyOffsets[recordIndex]=counts[topologyIndex]++;
        }else{
            topologyOffsets[recordIndex]=0xffffffffu;
        }
    }
    uint total=0u;
    for(uint topologyIndex=0u;topologyIndex<11u;++topologyIndex){
        topologyCounts[topologyIndex]=counts[topologyIndex];
        total+=counts[topologyIndex];
    }
    topologyCounts[11]=total;
}

kernel void emitCrowBodyVaneWork(
    device const uint* topologyIndices [[buffer(0)]],
    device const uint* topologyOffsets [[buffer(1)]],
    device const uint* topologyCounts [[buffer(2)]],
    device uint* recordWork [[buffer(3)]],
    constant CrowBodyVaneSelectionUniforms& selection [[buffer(4)]],
    uint index [[thread_position_in_grid]]) {
    if(index>=selection.counts.x){return;}
    uint topologyIndex=topologyIndices[index];
    if(topologyIndex>=11u){return;}
    uint base=0u;
    for(uint prior=0u;prior<topologyIndex;++prior){base+=topologyCounts[prior];}
    recordWork[base+topologyOffsets[index]]=index;
}

kernel void prepareCrowBodyVaneIndirectWork(
    device const uint* topologyCounts [[buffer(0)]],
    device DrawPrimitivesIndirectArguments* arguments [[buffer(1)]],
    device const CrowBodyVaneMorphologyGPU* records [[buffer(2)]],
    device const uint* recordWork [[buffer(3)]],
    uint topologyIndex [[thread_position_in_grid]]) {
    if(topologyIndex>=11u){return;}
    uint base=0u;
    for(uint prior=0u;prior<topologyIndex;++prior){base+=topologyCounts[prior];}
    uint2 sections=crowBodyVaneTopologySections(topologyIndex);
    uint vaneInstanceCount=0u;
    uint bodyInstanceCount=0u;
    for(uint local=0u;local<topologyCounts[topologyIndex];++local){
        uint recordIndex=recordWork[base+local];
        uint family=records[recordIndex].identity.x&0xff000000u;
        if(family!=0x07000000u){++vaneInstanceCount;}
        if(family==0x02000000u){
            ++bodyInstanceCount;
        }
    }
    arguments[topologyIndex]={
        sections.x*sections.y*6u,
        vaneInstanceCount,
        0u,
        base
    };
    uint rachisSections=sections.x<=4u?0u:
        (sections.x<=8u?4u:(sections.x<=12u?8u:12u));
    arguments[11u+topologyIndex]={
        rachisSections*24u,
        bodyInstanceCount,
        0u,
        base
    };
    uint detailSegments=sections.x<=4u?0u:
        (sections.x<=8u?43u:(sections.x<=12u?41u:167u));
    arguments[22u+topologyIndex]={
        detailSegments*18u,
        bodyInstanceCount,
        0u,
        base
    };
}

struct CrowBodyVaneDynamicState {
    float3 root;
    float3 tip;
    float3 normal;
    float rootWidth;
    float maximumWidth;
    float lateralSweep;
    float camber;
    float transverseCamber;
};

inline float crowBodyVaneSmoothstep(float value) {
    float bounded=clamp(value,0.0f,1.0f);
    return bounded*bounded*(3.0f-2.0f*bounded);
}

inline float crowBodyVaneDeploymentCamberScale(
    CrowBodyVaneMorphologyGPU record,float deployment) {
    uint region=uint(record.morphology.y);
    if(region!=1u){return 1.0f;}
    float axial=clamp(record.morphology.w,0.0f,23.0f)/23.0f;
    float axialWeight=crowBodyVaneSmoothstep(
        (axial-0.25f)/(1.0f-0.25f)
    );
    return 1.0f+(0.62f-1.0f)*axialWeight
        *crowBodyVaneSmoothstep(deployment);
}

inline float crowBodyVaneTransverseCamber(
    CrowBodyVaneMorphologyGPU record,float deployment) {
    uint region=uint(record.morphology.y);
    if(region==0u){return 0.12f;}
    if(region!=3u){return 0.12f;}
    float course=clamp(record.morphology.z,0.0f,21.0f)/21.0f;
    float courseWeight=crowBodyVaneSmoothstep(
        (course-0.40f)/(1.0f-0.40f)
    );
    return 0.12f+(0.08f-0.12f)*courseWeight
        *crowBodyVaneSmoothstep(deployment);
}

inline float crowCruralRadius(float fraction) {
    float bounded=clamp(fraction,0.0f,1.0f);
    return 0.014f*(1.0f-bounded)+0.0065f*bounded
        -0.002f*max(0.0f,fraction-1.0f)/0.10f;
}

inline float3 crowBodyVaneAffinePoint(
    CrowBodyVaneNeckTransformGPU transform,float3 point) {
    return float3(
        dot(transform.row0.xyz,point)+transform.row0.w,
        dot(transform.row1.xyz,point)+transform.row1.w,
        dot(transform.row2.xyz,point)+transform.row2.w
    );
}

inline float3 crowBodyVaneAffineDirection(
    CrowBodyVaneNeckTransformGPU transform,float3 direction) {
    return float3(
        dot(transform.row0.xyz,direction),
        dot(transform.row1.xyz,direction),
        dot(transform.row2.xyz,direction)
    );
}

struct CrowCranialRingGPU {
    float axial;
    float vertical;
    float halfWidth;
    float dorsal;
    float ventral;
};

inline float3 crowCranialSurfacePoint(
    CrowCranialRingGPU ring,float theta,float3 center,float3 radii) {
    float sine=sin(theta);
    float verticalRadius=sine>=0.0f?ring.dorsal:ring.ventral;
    return center+float3(
        radii.x*ring.axial,
        radii.y*ring.halfWidth*cos(theta),
        radii.z*(ring.vertical+verticalRadius*sine)
    );
}

inline float3 crowCranialNeckRotate(
    float3 vector,float coupling,
    device const CrowBodyVanePoseUniforms& pose,bool current) {
    float4 translationAndYaw=current
        ?pose.currentNeckTranslationAndYaw:pose.previousNeckTranslationAndYaw;
    float4 pitchRollAndActive=current
        ?pose.currentNeckPitchRollAndActive:pose.previousNeckPitchRollAndActive;
    if(pitchRollAndActive.z<0.5f){return vector;}
    float roll=pitchRollAndActive.y*coupling;
    float pitch=pitchRollAndActive.x*coupling;
    float yaw=translationAndYaw.w*coupling;
    float3 rolled=float3(
        vector.x,
        cos(roll)*vector.y-sin(roll)*vector.z,
        sin(roll)*vector.y+cos(roll)*vector.z
    );
    float3 pitched=float3(
        cos(pitch)*rolled.x+sin(pitch)*rolled.z,
        rolled.y,
        -sin(pitch)*rolled.x+cos(pitch)*rolled.z
    );
    return float3(
        cos(yaw)*pitched.x-sin(yaw)*pitched.y,
        sin(yaw)*pitched.x+cos(yaw)*pitched.y,
        pitched.z
    );
}

inline float crowCranialNeckCoupling(float axialOffset) {
    return crowBodyVaneSmoothstep((axialOffset-0.105f)/(0.156f-0.105f));
}

inline float3 crowCranialNeckPosition(
    float3 position,device const CrowBodyVanePoseUniforms& pose,bool current) {
    float4 centerAndDeployment=current
        ?pose.currentBodyCenterAndDeployment:pose.previousBodyCenterAndDeployment;
    float4 translationAndYaw=current
        ?pose.currentNeckTranslationAndYaw:pose.previousNeckTranslationAndYaw;
    float4 pitchRollAndActive=current
        ?pose.currentNeckPitchRollAndActive:pose.previousNeckPitchRollAndActive;
    if(pitchRollAndActive.z<0.5f){return position;}
    float coupling=crowCranialNeckCoupling(position.x-centerAndDeployment.x);
    float3 pivot=float3(0.096f,0.0f,0.038f);
    float3 local=position-centerAndDeployment.xyz-pivot;
    return centerAndDeployment.xyz+pivot
        +crowCranialNeckRotate(local,coupling,pose,current)
        +coupling*translationAndYaw.xyz;
}

inline float3 crowCranialNeckNormal(
    float3 normal,float3 position,
    device const CrowBodyVanePoseUniforms& pose,bool current) {
    float4 pitchRollAndActive=current
        ?pose.currentNeckPitchRollAndActive:pose.previousNeckPitchRollAndActive;
    float3 source=safeNormalizeCrow(normal,float3(0.0f,0.0f,1.0f));
    if(pitchRollAndActive.z<0.5f){return source;}
    float3 reference=abs(source.x)<0.8f
        ?float3(1.0f,0.0f,0.0f):float3(0.0f,1.0f,0.0f);
    float3 first=safeNormalizeCrow(
        cross(reference,source),float3(0.0f,1.0f,0.0f)
    );
    float3 second=cross(source,first);
    float step=0.0001f;
    float3 deformedFirst=crowCranialNeckPosition(
        position+step*first,pose,current
    )-crowCranialNeckPosition(position-step*first,pose,current);
    float3 deformedSecond=crowCranialNeckPosition(
        position+step*second,pose,current
    )-crowCranialNeckPosition(position-step*second,pose,current);
    float4 centerAndDeployment=current
        ?pose.currentBodyCenterAndDeployment:pose.previousBodyCenterAndDeployment;
    float coupling=crowCranialNeckCoupling(position.x-centerAndDeployment.x);
    return safeNormalizeCrow(
        cross(deformedFirst,deformedSecond),
        crowCranialNeckRotate(source,coupling,pose,current)
    );
}

inline float3 crowCervicalTerminalFlowOffset(
    CrowBodyVaneMorphologyGPU record) {
    if(uint(record.morphology.y)!=0u){return float3(0.0f);}
    uint row=uint(record.morphology.z);
    uint column=uint(record.morphology.w);
    uint inventoryIndex=record.identity.x&0x00ffffffu;
    uint sideIndex=inventoryIndex<448u?0u:1u;
    float side=sideIndex==0u?-1.0f:1.0f;
    float axialPhase=(float((row*17u+column*23u+sideIndex*11u)%37u)+0.5f)
        /37.0f-0.5f;
    float circumferentialPhase=
        (float((row*29u+column*13u+sideIndex*19u)%41u)+0.5f)
        /41.0f-0.5f;
    float axial=float(column)/13.0f;
    float boundaryEnvelope=0.55f+0.45f*sin(M_PI_F*axial);
    float shoulderOverlap=max(0.0f,1.0f-float(column)/3.0f);
    float3 tangent=safeNormalizeCrow(
        cross(float3(1.0f,0.0f,0.0f),record.normalAndCamber.xyz),
        float3(0.0f,side,0.0f)
    );
    return float3(
        0.0034f*axialPhase*boundaryEnvelope-0.0012f*shoulderOverlap,
        0.0f,0.0f
    )
        +tangent*(0.0019f*circumferentialPhase*boundaryEnvelope);
}

inline CrowBodyVaneDynamicState crowBodyVaneDynamicState(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current) {
    CrowBodyVaneDynamicState state;
    bool ventral=(record.identity.x&0xff000000u)==0x03000000u;
    bool femoral=(record.identity.x&0xff000000u)==0x04000000u;
    bool crural=(record.identity.x&0xff000000u)==0x05000000u;
    bool throatBridge=(record.identity.x&0xff000000u)==0x06000000u;
    bool cranial=(record.identity.x&0xff000000u)==0x07000000u;
    if(cranial){
        CrowCranialRingGPU ring={
            record.rootAndRootWidth.x,
            record.rootAndRootWidth.y,
            record.rootAndRootWidth.z,
            record.rootAndRootWidth.w,
            record.tipAndMaximumWidth.x
        };
        CrowCranialRingGPU previousRing={
            record.tipAndMaximumWidth.y,
            record.tipAndMaximumWidth.z,
            record.tipAndMaximumWidth.w,
            record.normalAndCamber.x,
            record.normalAndCamber.y
        };
        CrowCranialRingGPU nextRing={
            record.normalAndCamber.z,
            record.normalAndCamber.w,
            record.sweepAsymmetryAndRipple.x,
            record.sweepAsymmetryAndRipple.y,
            record.sweepAsymmetryAndRipple.z
        };
        float4 radiiAndBreathing=current
            ?pose.currentCranialRadiiAndBreathing
            :pose.previousCranialRadiiAndBreathing;
        float3 bodyCenter=current
            ?pose.currentBodyCenterAndDeployment.xyz
            :pose.previousBodyCenterAndDeployment.xyz;
        float3 center=bodyCenter+float3(0.158f,0.0f,0.052f);
        float3 radii=radiiAndBreathing.xyz
            *float3(radiiAndBreathing.w,1.0f,radiiAndBreathing.w);
        float theta=record.sweepAsymmetryAndRipple.w;
        float angularStep=M_PI_F/32.0f;
        float3 surface=crowCranialSurfacePoint(ring,theta,center,radii);
        float3 angularTangent=crowCranialSurfacePoint(
            ring,theta+angularStep,center,radii
        )-crowCranialSurfacePoint(ring,theta-angularStep,center,radii);
        float3 axialTangent=crowCranialSurfacePoint(
            nextRing,theta,center,radii
        )-crowCranialSurfacePoint(previousRing,theta,center,radii);
        float3 fallback=float3(0.0f,cos(theta),sin(theta));
        state.normal=safeNormalizeCrow(cross(angularTangent,axialTangent),fallback);
        bool throat=record.identity.w==10u;
        float3 direction=safeNormalizeCrow(
            -axialTangent
                +(throat?0.085f:0.035f)*record.envelopeAndTaper.z
                    *angularTangent
                +float3(0.0f,0.0f,throat?-0.16f:-0.035f)
                    *length(axialTangent),
            float3(-1.0f,0.0f,0.0f)
        );
        state.root=surface+0.00030f*state.normal;
        state.tip=state.root+record.envelopeAndTaper.x*direction
            +0.00020f*state.normal;
        float3 neighbour=crowCranialSurfacePoint(
            ring,theta+2.0f*angularStep,center,radii
        );
        float overlap=throat?0.75f:0.62f;
        state.maximumWidth=min(
            0.0048f,max(0.0024f,overlap*distance(surface,neighbour))
        );
        state.rootWidth=0.55f*state.maximumWidth;
        state.lateralSweep=0.0f;
        state.camber=record.envelopeAndTaper.y;
        state.transverseCamber=0.18f;
        return state;
    }
    if(throatBridge){
        uint column=uint(record.morphology.z);
        uint transformIndex=28u+column+(current?0u:4u);
        CrowBodyVaneNeckTransformGPU transform=neckTransforms[transformIndex];
        float3 bodyCenter=current
            ?pose.currentBodyCenterAndDeployment.xyz
            :pose.previousBodyCenterAndDeployment.xyz;
        state.root=bodyCenter+crowBodyVaneAffinePoint(
            transform,record.rootAndRootWidth.xyz
        );
        state.tip=bodyCenter+crowBodyVaneAffinePoint(
            transform,record.tipAndMaximumWidth.xyz
        );
        state.normal=safeNormalizeCrow(
            crowBodyVaneAffineDirection(transform,record.normalAndCamber.xyz),
            record.normalAndCamber.xyz
        );
        state.rootWidth=record.rootAndRootWidth.w;
        state.maximumWidth=record.tipAndMaximumWidth.w;
        state.lateralSweep=record.sweepAsymmetryAndRipple.x;
        state.camber=record.normalAndCamber.w;
        state.transverseCamber=as_type<float>(record.identity.z);
        return state;
    }
    if(crural){
        uint inventoryIndex=record.identity.x&0x00ffffffu;
        bool negativeSide=inventoryIndex<162u;
        device const float4* limbPose=(device const float4*)(
            neckTransforms+36u
        );
        float3 hip;
        float3 hock;
        if(current){
            hip=negativeSide?limbPose[2].xyz:limbPose[0].xyz;
            hock=negativeSide?limbPose[3].xyz:limbPose[1].xyz;
        }else{
            hip=negativeSide?limbPose[6].xyz:limbPose[4].xyz;
            hock=negativeSide?limbPose[7].xyz:limbPose[5].xyz;
        }
        float3 axis=safeNormalizeCrow(hock-hip,float3(0.0f,0.0f,-1.0f));
        float3 helper=abs(axis.z)<0.82f
            ?float3(0.0f,0.0f,1.0f):float3(0.0f,1.0f,0.0f);
        float3 first=safeNormalizeCrow(
            cross(axis,helper),float3(1.0f,0.0f,0.0f)
        );
        float3 second=safeNormalizeCrow(
            cross(axis,first),float3(0.0f,1.0f,0.0f)
        );
        float theta=record.rootAndRootWidth.y;
        float3 radial=cos(theta)*first+sin(theta)*second;
        float rootFraction=record.rootAndRootWidth.x;
        float tipFraction=record.rootAndRootWidth.z;
        state.root=mix(hip,hock,rootFraction)
            +crowCruralRadius(rootFraction)*radial;
        float3 tangential=safeNormalizeCrow(cross(axis,radial),second);
        float angularSweep=record.tipAndMaximumWidth.x;
        float3 tipRadial=safeNormalizeCrow(
            cos(angularSweep)*radial+sin(angularSweep)*tangential,radial
        );
        state.tip=mix(hip,hock,tipFraction)
            +(crowCruralRadius(tipFraction)+record.tipAndMaximumWidth.y)
                *tipRadial;
        state.normal=safeNormalizeCrow(0.82f*radial+0.18f*tipRadial,radial);
        state.rootWidth=record.rootAndRootWidth.w;
        state.maximumWidth=record.tipAndMaximumWidth.w;
        state.lateralSweep=record.sweepAsymmetryAndRipple.x;
        state.camber=record.normalAndCamber.w;
        state.transverseCamber=0.08f;
        return state;
    }
    if(femoral){
        uint inventoryIndex=record.identity.x&0x00ffffffu;
        bool negativeSide=inventoryIndex<270u;
        float4 centerAndDeployment=current
            ?pose.currentBodyCenterAndDeployment
            :pose.previousBodyCenterAndDeployment;
        device const float4* limbPose=(device const float4*)(
            neckTransforms+36u
        );
        float3 hip;
        float3 hock;
        if(current){
            hip=negativeSide?limbPose[2].xyz:limbPose[0].xyz;
            hock=negativeSide?limbPose[3].xyz:limbPose[1].xyz;
        }else{
            hip=negativeSide?limbPose[6].xyz:limbPose[4].xyz;
            hock=negativeSide?limbPose[7].xyz:limbPose[5].xyz;
        }
        float side=negativeSide?-1.0f:1.0f;
        float3 legAxis=safeNormalizeCrow(hock-hip,float3(0.0f,0.0f,-1.0f));
        float3 rootSurface=centerAndDeployment.xyz+record.rootAndRootWidth.xyz;
        float3 localNormal=record.tipAndMaximumWidth.xyz;
        state.root=rootSurface+0.0009f*localNormal;
        float3 rootRelativeToHip=rootSurface-hip;
        float3 radial=safeNormalizeCrow(
            rootRelativeToHip-legAxis*dot(rootRelativeToHip,legAxis),
            float3(0.0f,side,0.0f)
        );
        float3 tangential=safeNormalizeCrow(
            cross(legAxis,radial),float3(1.0f,0.0f,0.0f)
        );
        float3 bridgeTarget=mix(hip,hock,record.normalAndCamber.x)
            +(record.normalAndCamber.y+record.normalAndCamber.z)*radial
            +record.normalAndCamber.w*tangential;
        float3 bridgeVector=bridgeTarget-state.root;
        float bridgeDistance=length(bridgeVector);
        float vaneLength=min(0.034f,max(0.018f,0.68f*bridgeDistance))
            *record.morphology.z;
        float3 direction=safeNormalizeCrow(
            bridgeVector+0.20f*bridgeDistance*legAxis,legAxis
        );
        state.tip=state.root+vaneLength*direction;
        state.normal=safeNormalizeCrow(
            0.85f*localNormal+0.15f*radial,localNormal
        );
        state.maximumWidth=min(0.0076f,max(0.0041f,0.235f*vaneLength))
            *record.tipAndMaximumWidth.w;
        state.rootWidth=record.rootAndRootWidth.w*state.maximumWidth;
        state.lateralSweep=record.sweepAsymmetryAndRipple.x
            *state.maximumWidth;
        state.camber=record.morphology.w;
        state.transverseCamber=0.12f;
        return state;
    }
    state.root=record.rootAndRootWidth.xyz;
    state.tip=record.tipAndMaximumWidth.xyz
        +(ventral?float3(0.0f):crowCervicalTerminalFlowOffset(record));
    state.normal=record.normalAndCamber.xyz;
    uint region=uint(record.morphology.y);
    if(!ventral&&region==0u){
        uint column=min(uint(record.morphology.w),13u);
        uint transformIndex=(current?0u:14u)+column;
        CrowBodyVaneNeckTransformGPU transform=neckTransforms[transformIndex];
        state.root=crowBodyVaneAffinePoint(transform,state.root);
        state.tip=crowBodyVaneAffinePoint(transform,state.tip);
        state.normal=crowBodyVaneAffineDirection(transform,state.normal);
    }
    float4 centerAndDeployment=current
        ?pose.currentBodyCenterAndDeployment
        :pose.previousBodyCenterAndDeployment;
    state.root+=centerAndDeployment.xyz;
    state.tip+=centerAndDeployment.xyz;
    state.rootWidth=record.rootAndRootWidth.w;
    state.maximumWidth=record.tipAndMaximumWidth.w;
    state.lateralSweep=record.sweepAsymmetryAndRipple.x;
    state.camber=record.normalAndCamber.w*(ventral?1.0f:
        crowBodyVaneDeploymentCamberScale(record,centerAndDeployment.w));
    state.transverseCamber=ventral?as_type<float>(record.identity.z):
        crowBodyVaneTransverseCamber(record,centerAndDeployment.w);
    return state;
}

inline bool crowCranialBoundIntersectsFrustum(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    constant CrowCranialVisibilityUniforms& visibility) {
    CrowBodyVaneDynamicState state=crowBodyVaneDynamicState(
        record,pose,neckTransforms,true
    );
    float3 root=crowCranialNeckPosition(state.root,pose,true);
    float3 tip=crowCranialNeckPosition(state.tip,pose,true);
    float3 center=0.5f*(root+tip);
    float radius=0.5f*distance(root,tip)+state.maximumWidth
        +abs(state.camber)+0.00045f+visibility.selection.y;
    float4 point=float4(center,1.0f);
    return dot(visibility.leftPlane,point)>=-radius
        &&dot(visibility.rightPlane,point)>=-radius
        &&dot(visibility.bottomPlane,point)>=-radius
        &&dot(visibility.topPlane,point)>=-radius
        &&dot(visibility.nearPlane,point)>=-radius
        &&dot(visibility.farPlane,point)>=-radius;
}

inline bool crowCranialBoundOccluded(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    constant CrowCranialVisibilityUniforms& visibility,
    texture2d<float,access::read> previousDepth) {
    if(visibility.occlusionViewportBiasAndEnabled.w<0.5f){return false;}
    float2 viewport=visibility.occlusionViewportBiasAndEnabled.xy;
    if(any(viewport<1.0f)){return false;}
    CrowBodyVaneDynamicState state=crowBodyVaneDynamicState(
        record,pose,neckTransforms,false
    );
    float3 root=crowCranialNeckPosition(state.root,pose,false);
    float3 tip=crowCranialNeckPosition(state.tip,pose,false);
    float3 center=0.5f*(root+tip);
    float radius=0.5f*distance(root,tip)+state.maximumWidth
        +abs(state.camber)+0.00045f+visibility.selection.y;
    float2 minimumPixel=viewport;
    float2 maximumPixel=float2(0.0f);
    float nearestDepth=1.0f;
    for(uint corner=0u;corner<8u;++corner){
        float3 sign=float3(
            (corner&1u)==0u?-1.0f:1.0f,
            (corner&2u)==0u?-1.0f:1.0f,
            (corner&4u)==0u?-1.0f:1.0f
        );
        float4 clip=visibility.previousViewProjection
            *float4(center+sign*radius,1.0f);
        if(clip.w<=1.0e-6f){return false;}
        float3 ndc=clip.xyz/clip.w;
        if(ndc.z<=0.0f||ndc.z>=1.0f){return false;}
        float2 pixel=(ndc.xy*0.5f+0.5f)*viewport;
        minimumPixel=min(minimumPixel,pixel);
        maximumPixel=max(maximumPixel,pixel);
        nearestDepth=min(nearestDepth,ndc.z);
    }
    minimumPixel-=2.0f;
    maximumPixel+=2.0f;
    if(any(minimumPixel<0.0f)||any(maximumPixel>=viewport)){return false;}
    float maximumExtent=max(
        maximumPixel.x-minimumPixel.x,
        maximumPixel.y-minimumPixel.y
    );
    uint level=uint(floor(log2(max(maximumExtent,1.0f))));
    level=min(level,previousDepth.get_num_mip_levels()-1u);
    float scale=exp2(float(level));
    uint2 first=uint2(floor(minimumPixel/scale));
    uint2 last=uint2(floor(maximumPixel/scale));
    uint2 levelSize=uint2(
        previousDepth.get_width(level),previousDepth.get_height(level)
    );
    first=min(first,levelSize-1u);
    last=min(last,levelSize-1u);
    if(any(last-first>2u)){return false;}
    float maximumDepth=0.0f;
    for(uint y=0u;y<3u;++y){
        for(uint x=0u;x<3u;++x){
            uint2 coordinate=first+uint2(x,y);
            if(any(coordinate>last)){continue;}
            maximumDepth=max(
                maximumDepth,previousDepth.read(coordinate,level).x
            );
        }
    }
    if(maximumDepth>=0.999999f){return false;}
    return maximumDepth+visibility.occlusionViewportBiasAndEnabled.z
        <nearestDepth;
}

kernel void classifyCrowCranialVisibility(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(1)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(2)]],
    device uint* topologyIndices [[buffer(3)]],
    constant CrowCranialVisibilityUniforms& visibility [[buffer(4)]],
    texture2d<float,access::read> previousDepth [[texture(0)]],
    uint localIndex [[thread_position_in_grid]]) {
    if(localIndex>=visibility.counts.y){return;}
    uint recordIndex=visibility.counts.x+localIndex;
    CrowBodyVaneMorphologyGPU record=records[recordIndex];
    float projectedLength=max(
        0.0f,record.morphology.y*visibility.selection.x
    );
    uint topologyIndex=projectedLength>=480.0f?6u:
        (projectedLength>=120.0f?4u:
            (projectedLength>=24.0f?10u:0u));
    if((visibility.counts.w&8u)==0u||visibility.selection.x<1400.0f){
        topologyIndex=0xffffffffu;
    }
    if(topologyIndex>=visibility.counts.z
        ||!crowCranialBoundIntersectsFrustum(
            record,pose,neckTransforms,visibility
        )){
        topologyIndices[localIndex]=0xffffffffu;
        return;
    }
    bool occluded=crowCranialBoundOccluded(
        record,pose,neckTransforms,visibility,previousDepth
    );
    topologyIndices[localIndex]=topologyIndex|(occluded?0x80000000u:0u);
}

kernel void scanCrowCranialVisibility(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const uint* topologyIndices [[buffer(1)]],
    device uint* topologyOffsets [[buffer(2)]],
    device uint* gularOffsets [[buffer(3)]],
    device uint* counts [[buffer(4)]],
    constant CrowCranialVisibilityUniforms& visibility [[buffer(5)]],
    uint index [[thread_position_in_grid]]) {
    if(index>0u){return;}
    uint localCounts[11]={0u,0u,0u,0u,0u,0u,0u,0u,0u,0u,0u};
    uint gularCount=0u;
    uint frustumCount=0u;
    uint frustumGularCount=0u;
    uint occlusionCulled=0u;
    uint occlusionGularCulled=0u;
    bool occlusionEnabled=visibility.occlusionViewportBiasAndEnabled.w>=0.5f;
    for(uint localIndex=0u;localIndex<visibility.counts.y;++localIndex){
        uint classification=topologyIndices[localIndex];
        if(classification!=0xffffffffu){
            bool occluded=(classification&0x80000000u)!=0u;
            uint topologyIndex=classification&0x7fffffffu;
            uint recordIndex=visibility.counts.x+localIndex;
            bool gular=records[recordIndex].identity.w==10u;
            ++frustumCount;
            frustumGularCount+=gular?1u:0u;
            occlusionCulled+=occluded?1u:0u;
            occlusionGularCulled+=(occluded&&gular)?1u:0u;
            if(occluded){
                topologyOffsets[localIndex]=0xffffffffu;
                gularOffsets[localIndex]=0xffffffffu;
                continue;
            }
            topologyOffsets[localIndex]=localCounts[topologyIndex]++;
            if(gular){
                gularOffsets[localIndex]=gularCount++;
            }else{
                gularOffsets[localIndex]=0xffffffffu;
            }
        }else{
            topologyOffsets[localIndex]=0xffffffffu;
            gularOffsets[localIndex]=0xffffffffu;
        }
    }
    uint total=0u;
    for(uint topologyIndex=0u;topologyIndex<11u;++topologyIndex){
        counts[topologyIndex]=localCounts[topologyIndex];
        total+=localCounts[topologyIndex];
    }
    counts[11]=total;
    counts[12]=gularCount;
    counts[13]=frustumCount;
    counts[14]=frustumGularCount;
    counts[15]=occlusionCulled;
    counts[16]=occlusionEnabled?frustumCount:0u;
    counts[17]=occlusionGularCulled;
    counts[18]=occlusionEnabled?frustumGularCount:0u;
}

kernel void emitCrowCranialVisibilityWork(
    device const uint* topologyIndices [[buffer(1)]],
    device const uint* topologyOffsets [[buffer(2)]],
    device const uint* gularOffsets [[buffer(3)]],
    device const uint* counts [[buffer(4)]],
    device uint* recordWork [[buffer(5)]],
    device uint* gularWork [[buffer(6)]],
    constant CrowCranialVisibilityUniforms& visibility [[buffer(7)]],
    uint localIndex [[thread_position_in_grid]]) {
    if(localIndex>=visibility.counts.y){return;}
    uint topologyIndex=topologyIndices[localIndex];
    if(topologyIndex>=11u){return;}
    uint base=0u;
    for(uint prior=0u;prior<topologyIndex;++prior){base+=counts[prior];}
    uint recordIndex=visibility.counts.x+localIndex;
    recordWork[base+topologyOffsets[localIndex]]=recordIndex;
    if(gularOffsets[localIndex]!=0xffffffffu){
        gularWork[gularOffsets[localIndex]]=recordIndex;
    }
}

kernel void prepareCrowCranialVisibilityIndirectWork(
    device const uint* counts [[buffer(0)]],
    device DrawPrimitivesIndirectArguments* arguments [[buffer(1)]],
    uint workIndex [[thread_position_in_grid]]) {
    if(workIndex<11u){
        uint base=0u;
        for(uint prior=0u;prior<workIndex;++prior){base+=counts[prior];}
        uint2 sections=crowBodyVaneTopologySections(workIndex);
        arguments[workIndex]={
            sections.x*sections.y*6u,counts[workIndex],0u,base
        };
    }else if(workIndex==11u){
        arguments[11]={126u,counts[12],0u,0u};
    }
}

inline float3 crowBodyVaneUnwarpedPoint(
    CrowBodyVaneMorphologyGPU record,
    constant CrowBodyVaneGeometryUniforms& geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,
    uint axialIndex,
    uint widthIndex) {
    float localFraction=float(axialIndex)/float(geometry.counts.x);
    float start=clamp(record.morphology.x,0.0f,0.95f);
    float t=start+(1.0f-start)*localFraction;
    CrowBodyVaneDynamicState state=crowBodyVaneDynamicState(
        record,pose,neckTransforms,current
    );
    float3 normal=safeNormalizeCrow(state.normal,float3(0,0,1));
    float3 direction=safeNormalizeCrow(state.tip-state.root,float3(1,0,0));
    float3 widthAxis=safeNormalizeCrow(cross(normal,direction),float3(0,1,0));
    bool cranial=(record.identity.x&0xff000000u)==0x07000000u;
    float rootEnvelope=cranial?0.32f:
        clamp(record.envelopeAndTaper.y,0.05f,1.0f);
    float bodyEnvelope=rootEnvelope+(1.0f-rootEnvelope)
        *pow(max(sin(M_PI_F*t),0.0f),0.58f);
    float terminal=cranial?0.015f:
        clamp(record.envelopeAndTaper.z,0.0f,1.0f);
    float exponent=cranial?3.2f:
        clamp(record.envelopeAndTaper.w,2.0f,5.0f);
    float tipTaper=1.0f-(1.0f-terminal)*pow(t,exponent);
    float rippleEnvelope=pow(max(sin(M_PI_F*t),0.0f),2.0f);
    float ripple=cranial?1.0f:1.0f+record.sweepAsymmetryAndRipple.z
        *sin(2.0f*M_PI_F*record.envelopeAndTaper.x*t
            +record.sweepAsymmetryAndRipple.w)*rippleEnvelope;
    float width=mix(
        state.rootWidth,
        state.maximumWidth,t
    )*bodyEnvelope*tipTaper*ripple;
    float sine=sin(M_PI_F*t);
    float3 center=mix(state.root,state.tip,t)+normal*(state.camber*sine)
        +widthAxis*(state.lateralSweep*sine);
    float signedWidth=2.0f*float(widthIndex)/float(geometry.counts.y)-1.0f;
    float asymmetry=cranial?0.0f:record.sweepAsymmetryAndRipple.y;
    float localWidth=width*(1.0f+asymmetry*signedWidth);
    float3 point=center+widthAxis*(signedWidth*localWidth)
        +normal*(localWidth*state.transverseCamber
            *max(0.0f,1.0f-signedWidth*signedWidth));
    if(!cranial){return point;}
    // Qualitative, bounded contour relaxation. It is identity-stable and is
    // evaluated before shared cranial neck transport so beauty, AOV, motion,
    // and identity all receive identical geometry.
    float distal=pow(clamp(t,0.0f,1.0f),1.65f);
    float edgeEnvelope=1.0f-0.22f*signedWidth*signedWidth;
    float phase=3.0f*record.sweepAsymmetryAndRipple.w
        +0.37f*record.morphology.z+0.19f*record.morphology.w;
    float breathing=(current?pose.currentCranialRadiiAndBreathing.w:
        pose.previousCranialRadiiAndBreathing.w)-1.0f;
    float restingLift=0.00024f*(0.72f+0.28f*sin(phase));
    float breathingLift=0.012f*breathing;
    float lateralSet=0.000075f*cos(phase)*signedWidth;
    return point+distal*edgeEnvelope*(normal*(restingLift+breathingLift)
        +widthAxis*lateralSet);
}

inline float3 crowBodyVanePoint(
    CrowBodyVaneMorphologyGPU record,
    constant CrowBodyVaneGeometryUniforms& geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,
    uint axialIndex,
    uint widthIndex) {
    float3 point=crowBodyVaneUnwarpedPoint(
        record,geometry,pose,neckTransforms,current,axialIndex,widthIndex
    );
    return (record.identity.x&0xff000000u)==0x07000000u
        ?crowCranialNeckPosition(point,pose,current):point;
}

inline float3 crowBodyVaneNormal(
    CrowBodyVaneMorphologyGPU record,
    constant CrowBodyVaneGeometryUniforms& geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    uint2 gridIndex) {
    uint axialFirst=gridIndex.x>0u?gridIndex.x-1u:0u;
    uint axialSecond=min(geometry.counts.x,gridIndex.x+1u);
    uint widthFirst=gridIndex.y>0u?gridIndex.y-1u:0u;
    uint widthSecond=min(geometry.counts.y,gridIndex.y+1u);
    bool cranial=(record.identity.x&0xff000000u)==0x07000000u;
    float3 supplied=safeNormalizeCrow(
        crowBodyVaneDynamicState(record,pose,neckTransforms,true).normal,
        float3(0,0,1)
    );
    float3 axialDelta=crowBodyVaneUnwarpedPoint(
        record,geometry,pose,neckTransforms,true,axialSecond,gridIndex.y
    )-crowBodyVaneUnwarpedPoint(
        record,geometry,pose,neckTransforms,true,axialFirst,gridIndex.y
    );
    float3 widthDelta=crowBodyVaneUnwarpedPoint(
        record,geometry,pose,neckTransforms,true,gridIndex.x,widthSecond
    )-crowBodyVaneUnwarpedPoint(
        record,geometry,pose,neckTransforms,true,gridIndex.x,widthFirst
    );
    float3 resolved=safeNormalizeCrow(cross(axialDelta,widthDelta),supplied);
    resolved=dot(resolved,supplied)<0.0f?-resolved:resolved;
    if(!cranial){return resolved;}
    float3 sourcePoint=crowBodyVaneUnwarpedPoint(
        record,geometry,pose,neckTransforms,true,gridIndex.x,gridIndex.y
    );
    return crowCranialNeckNormal(resolved,sourcePoint,pose,true);
}

inline CrowFeatherVertexGPU crowBodyVaneProceduralVertex(
    device const CrowBodyVaneMorphologyGPU* records,
    constant CrowBodyVaneGeometryUniforms& geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    uint vertexIndex,
    uint instanceIndex) {
    CrowBodyVaneMorphologyGPU record=records[instanceIndex];
    uint2 gridIndex=crowBodyVaneGridIndex(vertexIndex,geometry);
    float localFraction=float(gridIndex.x)/float(geometry.counts.x);
    float start=clamp(record.morphology.x,0.0f,0.95f);
    float axial=start+(1.0f-start)*localFraction;
    float signedWidth=2.0f*float(gridIndex.y)/float(geometry.counts.y)-1.0f;
    CrowFeatherVertexGPU out;
    out.position=float4(crowBodyVanePoint(
        record,geometry,pose,neckTransforms,true,gridIndex.x,gridIndex.y
    ),1.0f);
    out.previousPosition=float4(crowBodyVanePoint(
        record,geometry,pose,neckTransforms,false,gridIndex.x,gridIndex.y
    ),1.0f);
    out.normal=float4(crowBodyVaneNormal(
        record,geometry,pose,neckTransforms,gridIndex
    ),0.0f);
    out.color=record.color;
    out.identity=record.identity;
    if((out.identity.x&0xff000000u)==0x03000000u){out.identity.z=1u;}
    out.parameters=float4(
        axial,signedWidth,record.sweepAsymmetryAndRipple.w,0.0f
    );
    return out;
}

inline uint crowBodyRachisSections(
    constant CrowBodyVaneGeometryUniforms& geometry) {
    uint axial=geometry.counts.x;
    return axial<=4u?0u:(axial<=8u?4u:(axial<=12u?8u:12u));
}

inline float crowBodyVaneHalfWidth(
    CrowBodyVaneMorphologyGPU record,float axial) {
    float rootEnvelope=clamp(record.envelopeAndTaper.y,0.05f,1.0f);
    float bodyEnvelope=rootEnvelope+(1.0f-rootEnvelope)
        *pow(max(sin(M_PI_F*axial),0.0f),0.58f);
    float terminal=clamp(record.envelopeAndTaper.z,0.0f,1.0f);
    float exponent=clamp(record.envelopeAndTaper.w,2.0f,5.0f);
    float tipTaper=1.0f-(1.0f-terminal)*pow(axial,exponent);
    float rippleEnvelope=pow(max(sin(M_PI_F*axial),0.0f),2.0f);
    float ripple=1.0f+record.sweepAsymmetryAndRipple.z
        *sin(2.0f*M_PI_F*record.envelopeAndTaper.x*axial
            +record.sweepAsymmetryAndRipple.w)*rippleEnvelope;
    return mix(record.rootAndRootWidth.w,record.tipAndMaximumWidth.w,axial)
        *bodyEnvelope*tipTaper*ripple;
}

inline float crowBodyRachisRetainedTransverseCamber(
    CrowBodyVaneMorphologyGPU record,
    CrowBodyVaneDynamicState state) {
    if(uint(record.morphology.y)!=3u){return 0.0f;}
    float course=clamp(record.morphology.z,0.0f,21.0f)/21.0f;
    return course>=0.40f?0.96f*state.transverseCamber:0.0f;
}

inline float3 crowBodyRachisCenter(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,float axial) {
    CrowBodyVaneDynamicState state=crowBodyVaneDynamicState(
        record,pose,neckTransforms,current
    );
    float3 direction=safeNormalizeCrow(
        state.tip-state.root,float3(-1.0f,0.0f,0.0f)
    );
    float3 normal=safeNormalizeCrow(
        state.normal-direction*dot(state.normal,direction),state.normal
    );
    float3 widthAxis=safeNormalizeCrow(
        cross(normal,direction),float3(0.0f,1.0f,0.0f)
    );
    float sine=sin(M_PI_F*axial);
    float retainedTransverse=crowBodyRachisRetainedTransverseCamber(
        record,state
    );
    return mix(state.root,state.tip,axial)
        +widthAxis*(record.sweepAsymmetryAndRipple.x*sine)
        +normal*(state.camber*sine
            +retainedTransverse*crowBodyVaneHalfWidth(record,axial)
            +0.00012f);
}

struct CrowBodyRachisQuad {
    float3 a;
    float3 b;
    float3 c;
    float3 d;
    float3 normal;
};

inline CrowBodyRachisQuad crowBodyRachisTubeQuad(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,float firstAxial,float secondAxial,uint radialSegment) {
    float3 start=crowBodyRachisCenter(
        record,pose,neckTransforms,current,firstAxial
    );
    float3 end=crowBodyRachisCenter(
        record,pose,neckTransforms,current,secondAxial
    );
    float3 axis=safeNormalizeCrow(end-start,float3(0.0f,0.0f,1.0f));
    float3 helper=abs(axis.z)<0.82f
        ?float3(0.0f,0.0f,1.0f):float3(0.0f,1.0f,0.0f);
    float3 first=safeNormalizeCrow(
        cross(axis,helper),float3(1.0f,0.0f,0.0f)
    );
    float3 second=safeNormalizeCrow(
        cross(axis,first),float3(0.0f,1.0f,0.0f)
    );
    uint next=(radialSegment+1u)%4u;
    float angle0=2.0f*M_PI_F*float(radialSegment)/4.0f;
    float angle1=2.0f*M_PI_F*float(next)/4.0f;
    float3 radial0=cos(angle0)*first+sin(angle0)*second;
    float3 radial1=cos(angle1)*first+sin(angle1)*second;
    float startRadius=mix(0.00022f,0.000055f,firstAxial);
    float endRadius=mix(0.00022f,0.000055f,secondAxial);
    CrowBodyRachisQuad result;
    result.a=start+startRadius*radial0;
    result.b=start+startRadius*radial1;
    result.c=end+endRadius*radial1;
    result.d=end+endRadius*radial0;
    result.normal=safeNormalizeCrow(
        cross(result.b-result.a,result.c-result.a),float3(0.0f,0.0f,1.0f)
    );
    return result;
}

inline float4 crowBodyRachisColor(CrowBodyVaneMorphologyGPU record) {
    uint region=uint(record.morphology.y);
    float base=region==0u?0.006f:(region==1u?0.0065f:
        (region==2u?0.0058f:0.0060f));
    float scale=region==0u?0.07f:(region==1u?0.09f:
        (region==2u?0.080f:0.085f));
    float material=(record.color.x/base-1.0f)/scale;
    return float4(
        0.010f*(1.0f+0.06f*material),
        0.014f*(1.0f+0.04f*material),
        0.022f*(1.0f+0.03f*material),0.14f
    );
}

inline CrowFeatherVertexGPU crowBodyRachisProceduralVertex(
    device const CrowBodyVaneMorphologyGPU* records,
    constant CrowBodyVaneGeometryUniforms& geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    uint vertexIndex,uint instanceIndex) {
    CrowBodyVaneMorphologyGPU record=records[instanceIndex];
    CrowFeatherVertexGPU out;
    if((record.identity.x&0xff000000u)!=0x02000000u){
        CrowBodyVaneDynamicState currentState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,true
        );
        CrowBodyVaneDynamicState previousState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,false
        );
        out.position=float4(currentState.root,1.0f);
        out.previousPosition=float4(previousState.root,1.0f);
        out.normal=float4(0.0f,0.0f,1.0f,0.0f);
        out.color=float4(0.0f);
        out.identity=record.identity;
        out.parameters=float4(0.0f);
        return out;
    }
    bool resolved=2.0f*record.tipAndMaximumWidth.w*geometry.selection.x<24.0f;
    uint sections=crowBodyRachisSections(geometry);
    if(!resolved||sections==0u){
        CrowBodyVaneDynamicState currentState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,true
        );
        CrowBodyVaneDynamicState previousState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,false
        );
        out.position=float4(currentState.root,1.0f);
        out.previousPosition=float4(previousState.root,1.0f);
        out.normal=float4(0.0f,0.0f,1.0f,0.0f);
        out.color=float4(0.0f);
        out.identity=record.identity;
        out.parameters=float4(0.0f);
        return out;
    }
    uint section=vertexIndex/24u;
    uint localVertex=vertexIndex-section*24u;
    uint radialSegment=localVertex/6u;
    uint corners[6]={0u,1u,2u,0u,2u,3u};
    uint corner=corners[localVertex%6u];
    float start=clamp(record.morphology.x,0.0f,0.95f);
    float firstAxial=start+(1.0f-start)*float(section)/float(sections);
    float secondAxial=start+(1.0f-start)*float(section+1u)/float(sections);
    CrowBodyRachisQuad currentQuad=crowBodyRachisTubeQuad(
        record,pose,neckTransforms,true,firstAxial,secondAxial,radialSegment
    );
    CrowBodyRachisQuad previousQuad=crowBodyRachisTubeQuad(
        record,pose,neckTransforms,false,firstAxial,secondAxial,radialSegment
    );
    float3 currentPoints[4]={
        currentQuad.a,currentQuad.b,currentQuad.c,currentQuad.d
    };
    float3 previousPoints[4]={
        previousQuad.a,previousQuad.b,previousQuad.c,previousQuad.d
    };
    out.position=float4(currentPoints[corner],1.0f);
    out.previousPosition=float4(previousPoints[corner],1.0f);
    out.normal=float4(currentQuad.normal,0.0f);
    out.color=crowBodyRachisColor(record);
    out.identity=record.identity;
    out.parameters=float4(0.5f,0.0f,0.0f,0.0f);
    return out;
}

struct CrowBodyDetailFrame {
    float3 root;
    float3 tip;
    float3 direction;
    float3 normal;
    float3 widthAxis;
    float camber;
    float transverseCamber;
};

struct CrowBodyDetailSegment {
    uint kind;
    float3 start;
    float3 end;
    float startRadius;
    float endRadius;
};

inline uint crowBodyDetailSegmentCount(
    CrowBodyVaneGeometryUniforms geometry) {
    uint axial=geometry.counts.x;
    return axial<=4u?0u:(axial<=8u?43u:(axial<=12u?41u:167u));
}

inline CrowBodyDetailFrame crowBodyDetailFrame(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current) {
    CrowBodyVaneDynamicState state=crowBodyVaneDynamicState(
        record,pose,neckTransforms,current
    );
    CrowBodyDetailFrame frame;
    frame.root=state.root;
    frame.tip=state.tip;
    frame.direction=safeNormalizeCrow(
        state.tip-state.root,float3(-1.0f,0.0f,0.0f)
    );
    frame.normal=safeNormalizeCrow(
        state.normal-frame.direction*dot(state.normal,frame.direction),
        state.normal
    );
    frame.widthAxis=safeNormalizeCrow(
        cross(frame.normal,frame.direction),float3(0.0f,1.0f,0.0f)
    );
    frame.camber=state.camber;
    frame.transverseCamber=state.transverseCamber;
    return frame;
}

inline float crowBodyDetailHalfWidth(
    CrowBodyVaneMorphologyGPU record,float axial,float signedWidth) {
    return crowBodyVaneHalfWidth(record,axial)
        *(1.0f+record.sweepAsymmetryAndRipple.y
            *clamp(signedWidth,-1.0f,1.0f));
}

inline float3 crowBodyDetailCenter(
    CrowBodyVaneMorphologyGPU record,CrowBodyDetailFrame frame,float axial) {
    float sine=sin(M_PI_F*axial);
    return mix(frame.root,frame.tip,axial)
        +frame.widthAxis*(record.sweepAsymmetryAndRipple.x*sine)
        +frame.normal*(frame.camber*sine+frame.transverseCamber
            *crowBodyDetailHalfWidth(record,axial,0.0f)+0.00012f);
}

inline float crowBodyDetailPennaceousAxial(
    CrowBodyVaneMorphologyGPU record,float localFraction) {
    float start=clamp(record.morphology.x,0.0f,0.95f);
    return start+(1.0f-start)*clamp(localFraction,0.0f,1.0f);
}

inline float crowBodyDetailTractSide(CrowBodyVaneMorphologyGPU record) {
    uint inventoryIndex=record.identity.x&0x00FFFFFFu;
    uint region=uint(record.morphology.y);
    uint base=0u;
    uint perSide=448u;
    if(region==1u){base=896u;perSide=480u;}
    else if(region==2u){base=1856u;perSide=150u;}
    else if(region>=3u){base=2156u;perSide=528u;}
    return inventoryIndex-base<perSide?-1.0f:1.0f;
}

inline CrowBodyDetailSegment crowBodyPrimaryDetailSegment(
    CrowBodyVaneMorphologyGPU record,
    CrowBodyVaneGeometryUniforms geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,uint pair,float side) {
    uint axialSections=geometry.counts.x;
    uint edgePairCount=axialSections<=8u?10u:(axialSections<=12u?9u:18u);
    uint baseBarbPairCount=axialSections<=8u?0u:edgePairCount;
    uint region=uint(record.morphology.y);
    float length=distance(record.rootAndRootWidth.xyz,record.tipAndMaximumWidth.xyz);
    bool promotesInterior=(region==2u||region==3u)
        &&length*geometry.selection.x>=40.0f;
    uint pairCount=promotesInterior
        ?max(baseBarbPairCount,edgePairCount):baseBarbPairCount;
    bool coarseEdgeOnly=pairCount==0u;
    float pixelsPerMeter=max(geometry.selection.x,1.0f);
    float aggregateRadius=min(0.00020f,max(0.000035f,0.30f/pixelsPerMeter));
    float baseExtension=min(0.0012f,max(0.00050f,1.10f/pixelsPerMeter));
    CrowBodyDetailFrame frame=crowBodyDetailFrame(
        record,pose,neckTransforms,current
    );
    int identityFirst=int(record.morphology.z)+31*int(region);
    float tractSide=crowBodyDetailTractSide(record);
    int identitySecond=int(record.morphology.w)+(tractSide<0.0f?97:0);
    float stationSpacing=0.77f/float(edgePairCount+1u);
    float featherPhase=float(identityFirst+1)*19.193f
        +float(identitySecond+1)*47.117f;
    float stationPhase=float(pair+1u)*11.731f;
    float stationIdentity=sin(featherPhase+stationPhase);
    float localAxial=0.10f+stationSpacing*float(pair+1u)
        +0.18f*stationSpacing*stationIdentity;
    float axial=crowBodyDetailPennaceousAxial(record,localAxial);
    float reachAxial=crowBodyDetailPennaceousAxial(
        record,min(0.94f,localAxial+0.035f+0.020f*localAxial)
    );
    float identity=sin(
        float(identityFirst+1)*12.9898f+float(identitySecond+1)*78.233f
        +float(pair+1u)*37.719f+side*1.371f
    );
    float3 start=crowBodyDetailCenter(record,frame,axial)
        +side*frame.widthAxis*crowBodyDetailHalfWidth(record,axial,side)
            *(coarseEdgeOnly?0.72f:0.0f)
        +frame.normal*(coarseEdgeOnly?0.00010f:0.00005f);
    float edgeExtension=baseExtension*(0.86f+0.14f*identity);
    float reachHalfWidth=crowBodyDetailHalfWidth(record,reachAxial,side);
    float lateralReach=coarseEdgeOnly
        ?reachHalfWidth+edgeExtension:0.97f*reachHalfWidth;
    float3 end=crowBodyDetailCenter(record,frame,reachAxial)
        +side*frame.widthAxis*lateralReach
        +frame.normal*(coarseEdgeOnly?0.00018f:0.00008f);
    CrowBodyDetailSegment segment;
    segment.kind=coarseEdgeOnly?1u:2u;
    segment.start=start;
    segment.end=end;
    segment.startRadius=coarseEdgeOnly?aggregateRadius:0.000050f;
    segment.endRadius=coarseEdgeOnly?0.58f*aggregateRadius:0.000018f;
    return segment;
}

inline float3 crowBodyPlumulaceousNode(
    CrowBodyVaneMorphologyGPU record,CrowBodyDetailFrame frame,
    float side,float startAxial,float endAxial,float reach,
    float identity,float fraction) {
    float axial=mix(startAxial,endAxial,fraction);
    float lateral=0.04f+reach*pow(fraction,0.78f);
    float inset=-0.00025f+0.00018f*fraction
        +0.00008f*sin(M_PI_F*fraction)*(0.60f+0.40f*identity);
    return crowBodyDetailCenter(record,frame,axial)
        +side*frame.widthAxis*crowBodyDetailHalfWidth(record,axial,side)
            *lateral
        +frame.normal*inset;
}

inline CrowBodyDetailSegment crowBodyPlumulaceousSegment(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,uint localIndex) {
    uint chain=localIndex/3u;
    uint section=localIndex-chain*3u;
    uint pair=chain/2u;
    float side=(chain&1u)==0u?-1.0f:1.0f;
    CrowBodyDetailFrame frame=crowBodyDetailFrame(
        record,pose,neckTransforms,current
    );
    uint region=uint(record.morphology.y);
    int identityFirst=int(record.morphology.z)+31*int(region);
    float tractSide=crowBodyDetailTractSide(record);
    int identitySecond=int(record.morphology.w)+(tractSide<0.0f?97:0);
    float identity=sin(
        float(identityFirst+1)*15.317f+float(identitySecond+1)*39.173f
        +float(pair+1u)*7.139f+side*1.913f
    );
    float startAxial=0.045f+0.025f*float(pair)+0.008f*identity;
    float endAxial=0.235f+0.035f*float(pair)+0.012f*identity;
    float reach=0.44f+0.06f*identity;
    float firstFraction=float(section)/3.0f;
    float secondFraction=float(section+1u)/3.0f;
    CrowBodyDetailSegment segment;
    segment.kind=4u;
    segment.start=crowBodyPlumulaceousNode(
        record,frame,side,startAxial,endAxial,reach,identity,firstFraction
    );
    segment.end=crowBodyPlumulaceousNode(
        record,frame,side,startAxial,endAxial,reach,identity,secondFraction
    );
    segment.startRadius=mix(0.000032f,0.000008f,firstFraction);
    segment.endRadius=mix(0.000032f,0.000008f,secondFraction);
    return segment;
}

inline CrowBodyDetailSegment crowBodyDetailSegmentAt(
    CrowBodyVaneMorphologyGPU record,
    CrowBodyVaneGeometryUniforms geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,uint segmentIndex) {
    uint axialSections=geometry.counts.x;
    uint edgePairCount=axialSections<=8u?10u:(axialSections<=12u?9u:18u);
    uint barbulesPerBarb=axialSections>12u?3u:0u;
    uint groupStride=1u+barbulesPerBarb;
    uint primaryBlock=edgePairCount*2u*groupStride;
    if(segmentIndex<primaryBlock){
        uint pairSide=segmentIndex/groupStride;
        uint within=segmentIndex-pairSide*groupStride;
        uint pair=pairSide/2u;
        float side=(pairSide&1u)==0u?-1.0f:1.0f;
        CrowBodyDetailSegment primary=crowBodyPrimaryDetailSegment(
            record,geometry,pose,neckTransforms,current,pair,side
        );
        if(within==0u){return primary;}
        CrowBodyDetailFrame frame=crowBodyDetailFrame(
            record,pose,neckTransforms,current
        );
        float3 barbDirection=safeNormalizeCrow(
            primary.end-primary.start,side*frame.widthAxis
        );
        float barbuleLength=min(
            0.0014f,0.22f*distance(primary.start,primary.end)
        );
        float fraction=float(within)/float(barbulesPerBarb+1u);
        float3 root=mix(primary.start,primary.end,fraction);
        float3 hookDirection=safeNormalizeCrow(
            0.82f*frame.direction-0.24f*side*frame.widthAxis
                +0.10f*barbDirection,
            frame.direction
        );
        CrowBodyDetailSegment barbule;
        barbule.kind=3u;
        barbule.start=root;
        barbule.end=root+barbuleLength*hookDirection;
        barbule.startRadius=0.000014f;
        barbule.endRadius=0.000006f;
        return barbule;
    }
    uint legacySegmentCount=primaryBlock+5u;
    if(segmentIndex>=legacySegmentCount){
        return crowBodyPlumulaceousSegment(
            record,pose,neckTransforms,current,
            segmentIndex-legacySegmentCount
        );
    }
    uint laneIndex=segmentIndex-primaryBlock;
    float lane=-1.0f+0.5f*float(laneIndex);
    float pixelsPerMeter=max(geometry.selection.x,1.0f);
    float aggregateRadius=min(0.00020f,max(0.000035f,0.30f/pixelsPerMeter));
    float baseExtension=min(0.0012f,max(0.00050f,1.10f/pixelsPerMeter));
    CrowBodyDetailFrame frame=crowBodyDetailFrame(
        record,pose,neckTransforms,current
    );
    uint region=uint(record.morphology.y);
    int identityFirst=int(record.morphology.z)+31*int(region);
    float tractSide=crowBodyDetailTractSide(record);
    int identitySecond=int(record.morphology.w)+(tractSide<0.0f?97:0);
    float featherPhase=float(identityFirst+1)*23.417f
        +float(identitySecond+1)*51.193f;
    float rootIdentity=sin(featherPhase+lane*5.173f);
    float rootAxial=0.88f+0.022f*rootIdentity;
    float3 root=crowBodyDetailCenter(record,frame,rootAxial)
        +lane*frame.widthAxis
            *crowBodyDetailHalfWidth(record,rootAxial,0.0f)*0.42f
        +frame.normal*0.00012f;
    float laneIdentity=sin(
        float(identityFirst+1)*17.117f+float(identitySecond+1)*43.731f
        +lane*2.913f
    );
    float tipReferenceHalfWidth=crowBodyDetailHalfWidth(record,0.88f,0.0f);
    float3 tip=frame.tip+frame.direction*baseExtension
        *(0.82f+0.12f*laneIdentity)
        +lane*frame.widthAxis*0.18f*tipReferenceHalfWidth
        +frame.normal*0.00020f;
    CrowBodyDetailSegment terminal;
    terminal.kind=1u;
    terminal.start=root;
    terminal.end=tip;
    terminal.startRadius=0.88f*aggregateRadius;
    terminal.endRadius=0.50f*aggregateRadius;
    return terminal;
}

inline CrowBodyRachisQuad crowBodyDetailRibbonQuad(
    CrowBodyDetailSegment segment,float3 surfaceNormal) {
    float3 axis=safeNormalizeCrow(
        segment.end-segment.start,float3(-1.0f,0.0f,0.0f)
    );
    float3 normal=safeNormalizeCrow(
        surfaceNormal-axis*dot(surfaceNormal,axis),surfaceNormal
    );
    float3 across=safeNormalizeCrow(
        cross(normal,axis),float3(0.0f,1.0f,0.0f)
    );
    CrowBodyRachisQuad result;
    result.a=segment.start-across*segment.startRadius;
    result.b=segment.start+across*segment.startRadius;
    result.c=segment.end+across*segment.endRadius;
    result.d=segment.end-across*segment.endRadius;
    result.normal=normal;
    return result;
}

inline CrowBodyRachisQuad crowBodyDetailTubeQuad(
    CrowBodyDetailSegment segment,uint radialSegment) {
    float3 axis=safeNormalizeCrow(
        segment.end-segment.start,float3(0.0f,0.0f,1.0f)
    );
    float3 helper=abs(axis.z)<0.82f
        ?float3(0.0f,0.0f,1.0f):float3(0.0f,1.0f,0.0f);
    float3 first=safeNormalizeCrow(
        cross(axis,helper),float3(1.0f,0.0f,0.0f)
    );
    float3 second=safeNormalizeCrow(
        cross(axis,first),float3(0.0f,1.0f,0.0f)
    );
    uint next=(radialSegment+1u)%3u;
    float angle0=2.0f*M_PI_F*float(radialSegment)/3.0f;
    float angle1=2.0f*M_PI_F*float(next)/3.0f;
    float3 radial0=cos(angle0)*first+sin(angle0)*second;
    float3 radial1=cos(angle1)*first+sin(angle1)*second;
    CrowBodyRachisQuad result;
    result.a=segment.start+segment.startRadius*radial0;
    result.b=segment.start+segment.startRadius*radial1;
    result.c=segment.end+segment.endRadius*radial1;
    result.d=segment.end+segment.endRadius*radial0;
    result.normal=safeNormalizeCrow(
        cross(result.b-result.a,result.c-result.a),float3(0.0f,0.0f,1.0f)
    );
    return result;
}

inline float4 crowBodyDetailColor(
    CrowBodyVaneMorphologyGPU record,uint kind) {
    if(kind==2u){return float4(0.008f,0.012f,0.020f,0.14f);}
    if(kind==3u){return float4(0.006f,0.010f,0.017f,0.14f);}
    if(kind==4u){return float4(0.0045f,0.0068f,0.0118f,0.12f);}
    uint region=uint(record.morphology.y);
    float base=region==0u?0.006f:(region==1u?0.0065f:
        (region==2u?0.0058f:0.0060f));
    float scale=region==0u?0.07f:(region==1u?0.09f:
        (region==2u?0.080f:0.085f));
    float material=(record.color.x/base-1.0f)/scale;
    return float4(
        0.0075f*(1.0f+0.08f*material),
        0.011f*(1.0f+0.06f*material),
        0.019f*(1.0f+0.04f*material),0.135f
    );
}

inline CrowFeatherVertexGPU crowBodyDetailProceduralVertex(
    device const CrowBodyVaneMorphologyGPU* records,
    CrowBodyVaneGeometryUniforms geometry,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    uint vertexIndex,uint instanceIndex) {
    CrowBodyVaneMorphologyGPU record=records[instanceIndex];
    if((record.identity.x&0xff000000u)!=0x02000000u){
        CrowFeatherVertexGPU out;
        CrowBodyVaneDynamicState currentState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,true
        );
        CrowBodyVaneDynamicState previousState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,false
        );
        out.position=float4(currentState.root,1.0f);
        out.previousPosition=float4(previousState.root,1.0f);
        out.normal=float4(0.0f,0.0f,1.0f,0.0f);
        out.color=float4(0.0f);
        out.identity=record.identity;
        out.parameters=float4(0.0f);
        return out;
    }
    uint segmentIndex=vertexIndex/18u;
    uint localVertex=vertexIndex-segmentIndex*18u;
    CrowBodyDetailSegment current=crowBodyDetailSegmentAt(
        record,geometry,pose,neckTransforms,true,segmentIndex
    );
    CrowBodyDetailSegment previous=crowBodyDetailSegmentAt(
        record,geometry,pose,neckTransforms,false,segmentIndex
    );
    uint corners[6]={0u,1u,2u,0u,2u,3u};
    uint corner=corners[localVertex%6u];
    CrowBodyRachisQuad currentQuad;
    CrowBodyRachisQuad previousQuad;
    if(current.kind==1u){
        CrowBodyDetailFrame currentFrame=crowBodyDetailFrame(
            record,pose,neckTransforms,true
        );
        CrowBodyDetailFrame previousFrame=crowBodyDetailFrame(
            record,pose,neckTransforms,false
        );
        currentQuad=crowBodyDetailRibbonQuad(current,currentFrame.normal);
        previousQuad=crowBodyDetailRibbonQuad(previous,previousFrame.normal);
        if(localVertex>=6u){corner=0u;}
    }else{
        currentQuad=crowBodyDetailTubeQuad(current,localVertex/6u);
        previousQuad=crowBodyDetailTubeQuad(previous,localVertex/6u);
    }
    float3 currentPoints[4]={
        currentQuad.a,currentQuad.b,currentQuad.c,currentQuad.d
    };
    float3 previousPoints[4]={
        previousQuad.a,previousQuad.b,previousQuad.c,previousQuad.d
    };
    CrowFeatherVertexGPU out;
    out.position=float4(currentPoints[corner],1.0f);
    out.previousPosition=float4(previousPoints[corner],1.0f);
    out.normal=float4(currentQuad.normal,0.0f);
    out.color=crowBodyDetailColor(record,current.kind);
    out.identity=record.identity;
    out.parameters=float4(0.5f,0.0f,0.0f,0.0f);
    return out;
}

kernel void emitCrowBodyDetailSegments(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const uint* topologyIndices [[buffer(1)]],
    device const uint* topologyCounts [[buffer(2)]],
    device const uint* recordWork [[buffer(3)]],
    device CrowBodyDetailSegmentGPU* output [[buffer(4)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(5)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(6)]],
    constant CrowBodyVaneSelectionUniforms& selection [[buffer(7)]],
    uint index [[thread_position_in_grid]]) {
    uint capacity=selection.counts.z;
    uint compactIndex=index/capacity;
    uint segmentIndex=index-compactIndex*capacity;
    if(compactIndex>=topologyCounts[11]){return;}
    uint recordIndex=recordWork[compactIndex];
    uint topologyIndex=topologyIndices[recordIndex];
    uint2 sections=crowBodyVaneTopologySections(topologyIndex);
    CrowBodyVaneGeometryUniforms geometry;
    uint detailSegments=sections.x<=4u?0u:
        (sections.x<=8u?43u:(sections.x<=12u?41u:167u));
    geometry.counts=uint4(sections.x,sections.y,0u,detailSegments*18u);
    geometry.selection=float4(
        selection.selection.x,float(capacity),0.0f,0.0f
    );
    uint segmentCount=crowBodyDetailSegmentCount(geometry);
    if(segmentIndex>=segmentCount){return;}
    CrowBodyVaneMorphologyGPU record=records[recordIndex];
    if((record.identity.x&0xff000000u)!=0x02000000u){
        CrowBodyVaneDynamicState currentState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,true
        );
        CrowBodyVaneDynamicState previousState=crowBodyVaneDynamicState(
            record,pose,neckTransforms,false
        );
        CrowBodyDetailSegmentGPU emitted;
        emitted.currentStartAndRadius=float4(currentState.root,0.0f);
        emitted.currentEndAndRadius=float4(currentState.root,0.0f);
        emitted.previousStartAndRadius=float4(previousState.root,0.0f);
        emitted.previousEndAndRadius=float4(previousState.root,0.0f);
        emitted.currentNormalAndKind=float4(0.0f,0.0f,1.0f,1.0f);
        emitted.previousNormalAndReserved=float4(0.0f,0.0f,1.0f,0.0f);
        output[index]=emitted;
        return;
    }
    CrowBodyDetailSegment current=crowBodyDetailSegmentAt(
        record,geometry,pose,neckTransforms,true,segmentIndex
    );
    CrowBodyDetailSegment previous=crowBodyDetailSegmentAt(
        record,geometry,pose,neckTransforms,false,segmentIndex
    );
    CrowBodyDetailFrame currentFrame=crowBodyDetailFrame(
        record,pose,neckTransforms,true
    );
    CrowBodyDetailFrame previousFrame=crowBodyDetailFrame(
        record,pose,neckTransforms,false
    );
    CrowBodyDetailSegmentGPU emitted;
    emitted.currentStartAndRadius=float4(current.start,current.startRadius);
    emitted.currentEndAndRadius=float4(current.end,current.endRadius);
    emitted.previousStartAndRadius=float4(previous.start,previous.startRadius);
    emitted.previousEndAndRadius=float4(previous.end,previous.endRadius);
    emitted.currentNormalAndKind=float4(currentFrame.normal,float(current.kind));
    emitted.previousNormalAndReserved=float4(previousFrame.normal,0.0f);
    output[index]=emitted;
}

kernel void probeCrowBodyVaneVertices(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(3)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(4)]],
    uint index [[thread_position_in_grid]]) {
    uint instanceIndex=index/geometry.counts.w;
    uint vertexIndex=index-instanceIndex*geometry.counts.w;
    if(instanceIndex>=geometry.counts.z){return;}
    output[index]=crowBodyVaneProceduralVertex(
        records,geometry,pose,neckTransforms,vertexIndex,instanceIndex
    );
}

kernel void probeCrowBodyRachisVertices(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(3)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(4)]],
    uint index [[thread_position_in_grid]]) {
    uint instanceIndex=index/geometry.counts.w;
    uint vertexIndex=index-instanceIndex*geometry.counts.w;
    if(instanceIndex>=geometry.counts.z){return;}
    output[index]=crowBodyRachisProceduralVertex(
        records,geometry,pose,neckTransforms,vertexIndex,instanceIndex
    );
}

kernel void probeCrowBodyDetailVertices(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(3)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(4)]],
    uint index [[thread_position_in_grid]]) {
    uint instanceIndex=index/geometry.counts.w;
    uint vertexIndex=index-instanceIndex*geometry.counts.w;
    if(instanceIndex>=geometry.counts.z){return;}
    output[index]=crowBodyDetailProceduralVertex(
        records,geometry,pose,neckTransforms,vertexIndex,instanceIndex
    );
}

vertex CrowRasterVertex crowBodyVaneAOVVertex(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const uint* recordWork [[buffer(1)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(2)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(3)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(4)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(5)]],
    uint vertexIndex [[vertex_id]],
    uint instanceIndex [[instance_id]]) {
    CrowFeatherVertexGPU source=crowBodyVaneProceduralVertex(
        records,geometry,pose,neckTransforms,
        vertexIndex,recordWork[instanceIndex]
    );
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowSurfaceBiasedClipPosition(
        camera.viewProjection*source.position,featherClass
    );
    out.previousClipPosition=crowSurfaceBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass
    );
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.albedoAndMaterial=source.color;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=float3(0.0f);
    out.identity=source.identity;
    return out;
}

vertex CrowRasterVertex crowBodyRachisAOVVertex(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const uint* recordWork [[buffer(1)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(2)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(3)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(4)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(5)]],
    uint vertexIndex [[vertex_id]],
    uint instanceIndex [[instance_id]]) {
    CrowFeatherVertexGPU source=crowBodyRachisProceduralVertex(
        records,geometry,pose,neckTransforms,
        vertexIndex,recordWork[instanceIndex]
    );
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowSurfaceBiasedClipPosition(
        camera.viewProjection*source.position,featherClass
    );
    out.previousClipPosition=crowSurfaceBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass
    );
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.albedoAndMaterial=source.color;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=float3(0.0f);
    out.identity=source.identity;
    return out;
}

vertex CrowRasterVertex crowBodyDetailAOVVertex(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const uint* recordWork [[buffer(1)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(2)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(3)]],
    device const CrowBodyDetailSegmentGPU* segments [[buffer(6)]],
    uint vertexIndex [[vertex_id]],
    uint instanceIndex [[instance_id]]) {
    uint segmentIndex=vertexIndex/18u;
    uint localVertex=vertexIndex-segmentIndex*18u;
    uint capacity=uint(geometry.selection.y);
    CrowBodyDetailSegmentGPU retained=
        segments[instanceIndex*capacity+segmentIndex];
    uint kind=uint(retained.currentNormalAndKind.w);
    CrowBodyDetailSegment current;
    current.kind=kind;
    current.start=retained.currentStartAndRadius.xyz;
    current.end=retained.currentEndAndRadius.xyz;
    current.startRadius=retained.currentStartAndRadius.w;
    current.endRadius=retained.currentEndAndRadius.w;
    CrowBodyDetailSegment previous;
    previous.kind=kind;
    previous.start=retained.previousStartAndRadius.xyz;
    previous.end=retained.previousEndAndRadius.xyz;
    previous.startRadius=retained.previousStartAndRadius.w;
    previous.endRadius=retained.previousEndAndRadius.w;
    uint corners[6]={0u,1u,2u,0u,2u,3u};
    uint corner=corners[localVertex%6u];
    CrowBodyRachisQuad currentQuad;
    CrowBodyRachisQuad previousQuad;
    if(kind==1u){
        currentQuad=crowBodyDetailRibbonQuad(
            current,retained.currentNormalAndKind.xyz
        );
        previousQuad=crowBodyDetailRibbonQuad(
            previous,retained.previousNormalAndReserved.xyz
        );
        if(localVertex>=6u){corner=0u;}
    }else{
        currentQuad=crowBodyDetailTubeQuad(current,localVertex/6u);
        previousQuad=crowBodyDetailTubeQuad(previous,localVertex/6u);
    }
    float3 currentPoints[4]={
        currentQuad.a,currentQuad.b,currentQuad.c,currentQuad.d
    };
    float3 previousPoints[4]={
        previousQuad.a,previousQuad.b,previousQuad.c,previousQuad.d
    };
    uint recordIndex=recordWork[instanceIndex];
    CrowBodyVaneMorphologyGPU record=records[recordIndex];
    CrowFeatherVertexGPU source;
    source.position=float4(currentPoints[corner],1.0f);
    source.previousPosition=float4(previousPoints[corner],1.0f);
    source.normal=float4(currentQuad.normal,0.0f);
    source.color=crowBodyDetailColor(record,kind);
    source.identity=record.identity;
    source.parameters=float4(0.5f,0.0f,0.0f,0.0f);
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowSurfaceBiasedClipPosition(
        camera.viewProjection*source.position,featherClass
    );
    out.previousClipPosition=crowSurfaceBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass
    );
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.albedoAndMaterial=source.color;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=float3(0.0f);
    out.identity=source.identity;
    return out;
}

inline float3 crowGularDetailCenter(
    CrowBodyVaneDynamicState state,float fraction) {
    return state.root+fraction*(state.tip-state.root)
        +state.normal*(state.camber*sin(M_PI_F*fraction)+0.00010f);
}

inline float crowGularDetailHalfWidth(
    CrowBodyVaneDynamicState state,float fraction) {
    float envelope=0.32f+0.68f
        *pow(max(sin(M_PI_F*fraction),0.0f),0.58f);
    float tipTaper=1.0f-0.985f*pow(fraction,3.2f);
    return mix(state.rootWidth,state.maximumWidth,fraction)
        *envelope*tipTaper;
}

inline CrowBodyDetailSegment crowGularDetailSegment(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    bool current,uint segmentIndex) {
    CrowBodyVaneDynamicState state=crowBodyVaneDynamicState(
        record,pose,neckTransforms,current
    );
    float3 direction=safeNormalizeCrow(
        state.tip-state.root,float3(-1.0f,0.0f,0.0f)
    );
    float3 normal=safeNormalizeCrow(
        state.normal-direction*dot(state.normal,direction),state.normal
    );
    state.normal=normal;
    float3 widthAxis=safeNormalizeCrow(
        cross(normal,direction),float3(0.0f,1.0f,0.0f)
    );
    CrowBodyDetailSegment segment;
    if(segmentIndex==0u){
        segment.kind=0u;
        segment.start=crowGularDetailCenter(state,0.16f);
        segment.end=crowGularDetailCenter(state,0.94f);
        segment.startRadius=0.00017f;
        segment.endRadius=0.000045f;
    }else{
        uint local=segmentIndex-1u;
        uint pair=local/2u;
        float side=(local&1u)==0u?-1.0f:1.0f;
        float axial=0.32f+0.18f*float(pair);
        float reach=axial+0.075f;
        segment.kind=1u;
        segment.start=crowGularDetailCenter(state,axial)+normal*0.00006f;
        segment.end=crowGularDetailCenter(state,reach)
            +side*widthAxis*(crowGularDetailHalfWidth(state,reach)+0.00045f)
            +normal*0.00012f;
        segment.startRadius=0.000075f;
        segment.endRadius=0.000025f;
    }
    segment.start=crowCranialNeckPosition(segment.start,pose,current);
    segment.end=crowCranialNeckPosition(segment.end,pose,current);
    return segment;
}

inline CrowFeatherVertexGPU crowGularDetailProceduralVertex(
    CrowBodyVaneMorphologyGPU record,
    device const CrowBodyVanePoseUniforms& pose,
    device const CrowBodyVaneNeckTransformGPU* neckTransforms,
    uint vertexIndex) {
    bool active=(record.identity.x&0xff000000u)==0x07000000u
        &&record.identity.w==10u;
    uint segmentIndex=vertexIndex/18u;
    uint localVertex=vertexIndex-segmentIndex*18u;
    CrowBodyDetailSegment current=crowGularDetailSegment(
        record,pose,neckTransforms,true,segmentIndex
    );
    CrowBodyDetailSegment previous=crowGularDetailSegment(
        record,pose,neckTransforms,false,segmentIndex
    );
    if(!active){
        current.end=current.start;
        previous.end=previous.start;
        current.startRadius=0.0f;
        current.endRadius=0.0f;
        previous.startRadius=0.0f;
        previous.endRadius=0.0f;
    }
    uint corners[6]={0u,1u,2u,0u,2u,3u};
    uint corner=corners[localVertex%6u];
    CrowBodyRachisQuad currentQuad=crowBodyDetailTubeQuad(
        current,localVertex/6u
    );
    CrowBodyRachisQuad previousQuad=crowBodyDetailTubeQuad(
        previous,localVertex/6u
    );
    float3 currentPoints[4]={
        currentQuad.a,currentQuad.b,currentQuad.c,currentQuad.d
    };
    float3 previousPoints[4]={
        previousQuad.a,previousQuad.b,previousQuad.c,previousQuad.d
    };
    CrowFeatherVertexGPU out;
    out.position=float4(currentPoints[corner],1.0f);
    out.previousPosition=float4(previousPoints[corner],1.0f);
    out.normal=float4(currentQuad.normal,0.0f);
    out.color=segmentIndex==0u
        ?float4(0.0048f,0.0072f,0.0125f,0.13f)
        :float4(0.0055f,0.0084f,0.0145f,0.12f);
    if(!active){out.color=float4(0.0f);}
    out.identity=record.identity;
    out.parameters=float4(0.5f,0.0f,0.0f,0.0f);
    return out;
}

kernel void probeCrowGularDetailVertices(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    constant CrowBodyVaneGeometryUniforms& geometry [[buffer(1)]],
    device CrowFeatherVertexGPU* output [[buffer(2)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(3)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(4)]],
    uint index [[thread_position_in_grid]]) {
    uint instanceIndex=index/geometry.counts.w;
    uint vertexIndex=index-instanceIndex*geometry.counts.w;
    if(instanceIndex>=geometry.counts.z){return;}
    output[index]=crowGularDetailProceduralVertex(
        records[instanceIndex],pose,neckTransforms,vertexIndex
    );
}

kernel void probeCrowGularDetailSegments(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device CrowBodyDetailSegmentGPU* output [[buffer(1)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(2)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(3)]],
    uint index [[thread_position_in_grid]]) {
    if(index>=7u){return;}
    CrowBodyDetailSegment current=crowGularDetailSegment(
        records[0],pose,neckTransforms,true,index
    );
    CrowBodyDetailSegment previous=crowGularDetailSegment(
        records[0],pose,neckTransforms,false,index
    );
    CrowBodyDetailSegmentGPU emitted;
    emitted.currentStartAndRadius=float4(current.start,current.startRadius);
    emitted.currentEndAndRadius=float4(current.end,current.endRadius);
    emitted.previousStartAndRadius=float4(previous.start,previous.startRadius);
    emitted.previousEndAndRadius=float4(previous.end,previous.endRadius);
    emitted.currentNormalAndKind=float4(0.0f,0.0f,1.0f,float(current.kind));
    emitted.previousNormalAndReserved=float4(0.0f,0.0f,1.0f,0.0f);
    output[index]=emitted;
}

vertex CrowRasterVertex crowGularDetailAOVVertex(
    device const CrowBodyVaneMorphologyGPU* records [[buffer(0)]],
    device const uint* recordWork [[buffer(1)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(3)]],
    device const CrowBodyVanePoseUniforms& pose [[buffer(4)]],
    device const CrowBodyVaneNeckTransformGPU* neckTransforms [[buffer(5)]],
    uint vertexIndex [[vertex_id]],
    uint instanceIndex [[instance_id]]) {
    uint recordIndex=recordWork[instanceIndex];
    CrowFeatherVertexGPU source=crowGularDetailProceduralVertex(
        records[recordIndex],pose,neckTransforms,vertexIndex
    );
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowSurfaceBiasedClipPosition(
        camera.viewProjection*source.position,featherClass
    );
    out.previousClipPosition=crowSurfaceBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass
    );
    out.world=source.position.xyz;
    out.normal=source.normal.xyz;
    out.albedoAndMaterial=source.color;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=float3(0.0f);
    out.identity=source.identity;
    return out;
}

vertex CrowRasterVertex crowSurfaceAOVVertex(
    device const CrowSurfaceTemporalVertexGPU* vertices [[buffer(0)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    CrowSurfaceTemporalVertexGPU source=vertices[vid];
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowSurfaceBiasedClipPosition(
        camera.viewProjection*source.position,featherClass
    );
    out.previousClipPosition=crowSurfaceBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass
    );
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.albedoAndMaterial=source.albedoAndMaterial;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=float3(0.0f);
    out.identity=source.identity;
    return out;
}

vertex CrowRasterVertex crowFeatherAOVVertex(
    device const CrowFeatherVertexGPU* vertices [[buffer(0)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    CrowFeatherVertexGPU source=vertices[vid];
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowRectrixDetailBiasedClipPosition(
        camera.viewProjection*source.position,featherClass,source.parameters.w
    );
    out.previousClipPosition=crowRectrixDetailBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass,
        source.parameters.w
    );
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.albedoAndMaterial=source.color;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=float3(0.0f);
    out.identity=source.identity;
    // Preserve the anatomical feather owner while making vane, rachis, and
    // barb survival measurable after projection. Persistent physics surface
    // identifiers occupy the low 24 bits; the detail kind is diagnostic-only.
    uint detailKind=uint(clamp(source.parameters.w,0.0f,255.0f)+0.5f);
    out.identity.z=(source.identity.z&0x00ffffffu)|(detailKind<<24u);
    return out;
}

// The compact interval list is already the authoritative production geometry.
// Pull its vertices in raster so close-up detail does not require a second,
// candidate-sized materialized vertex stream. The compute expansion above is
// retained as the byte-for-byte audit oracle.
vertex CrowRasterVertex crowVentralBarbAOVVertex(
    device const CrowVentralRachisCurveRecordGPU* records [[buffer(0)]],
    device const CrowVentralBarbSegmentWorkGPU* work [[buffer(1)]],
    constant CrowVentralBarbGeometryUniforms& geometry [[buffer(2)]],
    constant CrowTemporalCameraUniforms& camera [[buffer(3)]],
    uint vid [[vertex_id]]) {
    CrowFeatherVertexGPU source=crowVentralBarbProceduralVertex(
        records,work,geometry,vid
    );
    CrowRasterVertex out;
    uint featherClass=source.identity.w&255u;
    out.position=crowSurfaceBiasedClipPosition(
        camera.viewProjection*source.position,featherClass
    );
    out.previousClipPosition=crowSurfaceBiasedClipPosition(
        camera.previousViewProjection*source.previousPosition,featherClass
    );
    out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);
    out.albedoAndMaterial=source.color;
    out.featherCoordinates=source.parameters.xyz;
    out.resolvedCurveTangent=crowVentralBarbProceduralTangent(
        records,work,geometry,vid
    );
    out.identity=source.identity;
    return out;
}

vertex RasterVertex isoSurfaceVertex(
    device const IsoVertex* vertices [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    constant VisualizationUniforms& u [[buffer(2)]],
    uint vid [[vertex_id]]) {
    IsoVertex source=vertices[vid];RasterVertex out;
    out.position=camera.viewProjection*source.position;out.world=source.position.xyz;
    float scalar=(u.flags.y&32u)!=0u?source.normal.w:u.tracerAndIso.y;
    float range=(u.flags.y&32u)!=0u?u.displayOptions.z:u.displayOptions.w;
    out.normal=normalize(source.normal.xyz);out.color=float4(sequentialMap(scalar/range),u.tracerAndIso.z);out.uv=float2(0);return out;
}

fragment float4 isoFragment(
    RasterVertex in [[stage_in]],
    constant VisualizationUniforms& u [[buffer(0)]]) {
    if ((u.flags.y & 16u) != 0u
        && dot(in.world-u.sliceCenterAndOpacity.xyz,u.sliceNormalAndRange.xyz)<0.0f)
        discard_fragment();
    float light=0.28f+0.72f*abs(dot(in.normal,normalize(float3(0.4f,-0.5f,0.75f))));
    return float4(in.color.rgb*light,in.color.a);
}

fragment float4 litFragment(RasterVertex in [[stage_in]]) {
    float light=0.28f+0.72f*abs(dot(in.normal,normalize(float3(0.4f,-0.5f,0.75f))));
    return float4(in.color.rgb*light,in.color.a);
}

fragment float4 showcaseDoveFragment(
    RasterVertex in [[stage_in]],
    constant CameraUniforms& camera [[buffer(0)]]) {
    float3 normal=in.normal;
    float3 view=normalize(camera.eyeAndWidth.xyz-in.world);
    float3 key=normalize(float3(0.38f,-0.48f,0.80f));
    float3 fill=normalize(float3(-0.72f,0.22f,0.46f));
    float keyLight=abs(dot(normal,key));
    float fillLight=abs(dot(normal,fill));
    float diffuse=0.25f+0.64f*keyLight+0.13f*fillLight;
    float rim=pow(1.0f-abs(dot(normal,view)),2.35f);
    float3 halfVector=normalize(key+view);
    float specular=pow(abs(dot(normal,halfVector)),38.0f);
    float3 color=in.color.rgb*diffuse;
    color+=rim*mix(float3(0.05f,0.28f,0.48f),in.color.rgb,0.38f);
    color+=0.22f*specular*float3(0.72f,0.90f,1.0f);
    color=1.0f-exp(-1.08f*color);
    return float4(color,in.color.a);
}

inline float3 crowFeatherAxis(
    float3 world,
    float3 normal,
    float2 featherCoordinates) {
    float3 dpdx=dfdx(world);
    float3 dpdy=dfdy(world);
    float2 duvdx=dfdx(featherCoordinates);
    float2 duvdy=dfdy(featherCoordinates);
    float determinant=duvdx.x*duvdy.y-duvdx.y*duvdy.x;
    float3 fallback=abs(normal.x)<0.86f
        ?float3(-1.0f,0.0f,0.0f)
        :float3(0.0f,1.0f,0.0f);
    fallback=safeNormalizeCrow(
        fallback-normal*dot(fallback,normal),float3(0.0f,0.0f,1.0f)
    );
    float3 axis=abs(determinant)>1.0e-8f
        ?(duvdy.y*dpdx-duvdx.y*dpdy)/determinant
        :fallback;
    axis-=normal*dot(axis,normal);
    return safeNormalizeCrow(axis,fallback);
}

inline float crowFeatherAnisotropicLobe(
    float3 normal,
    float3 featherAxis,
    float3 halfVector,
    float longitudinalRoughness,
    float transverseRoughness) {
    float3 barbAxis=safeNormalizeCrow(
        cross(normal,featherAxis),float3(0.0f,1.0f,0.0f)
    );
    float normalHalf=max(abs(dot(normal,halfVector)),0.055f);
    float longitudinal=dot(featherAxis,halfVector)/longitudinalRoughness;
    float transverse=dot(barbAxis,halfVector)/transverseRoughness;
    float exponent=-(longitudinal*longitudinal+transverse*transverse)
        /(normalHalf*normalHalf);
    return exp(max(exponent,-80.0f))*sqrt(normalHalf);
}

/// Box-filter a procedural sine in screen space and fade it before its phase
/// crosses the pixel Nyquist limit. Close views retain the resolved barb
/// pattern; distant vanes converge to their mean instead of forming stippled
/// or crawling diagonal bands.
inline float crowBandLimitedSine(float phase) {
    float footprint=max(abs(dfdx(phase)),abs(dfdy(phase)));
    float halfFootprint=0.5f*footprint;
    float boxAmplitude=halfFootprint>1.0e-4f
        ?sin(halfFootprint)/halfFootprint
        :1.0f;
    float nyquistFade=1.0f-smoothstep(2.2f,M_PI_F,footprint);
    return sin(phase)*max(boxAmplitude,0.0f)*nyquistFade;
}

constant float crowBodyRachisFadeStartPixels=12.0f;
constant float crowBodyRachisFadeEndPixels=24.0f;

/// Resolve a transverse feather feature only when its owning vane spans enough
/// final-output pixels. The derivative form is conservative under grazing
/// projection: a shaft cannot survive merely because the vane is long when its
/// width has collapsed below useful discrimination.
inline float crowResolvedTransverseFeatureVisibility(
    float projectedSpanPixels,
    float fadeStartPixels,
    float fadeEndPixels) {
    return smoothstep(
        fadeStartPixels,
        fadeEndPixels,
        max(projectedSpanPixels,0.0f)
    );
}

inline float crowScreenResolvedTransverseFeatureVisibility(
    float signedTransverseCoordinate,
    float fadeStartPixels,
    float fadeEndPixels) {
    float coordinateFootprint=max(
        abs(dfdx(signedTransverseCoordinate)),
        abs(dfdy(signedTransverseCoordinate))
    );
    float projectedSpanPixels=2.0f/max(coordinateFootprint,1.0e-4f);
    return crowResolvedTransverseFeatureVisibility(
        projectedSpanPixels,
        fadeStartPixels,
        fadeEndPixels
    );
}

// Eight equal-energy visible samples keep the black-plumage response in a
// wavelength domain until the final display conversion. The signed weights
// are a normalized CIE 1931 2-degree / linear-sRGB quadrature: an equal value
// in every band reconstructs neutral white. Increasing the sample count later
// changes only this table and the bounded loop below, rather than another set
// of hand-authored RGB feather tints.
constant float crowPlumageWavelengthNanometers[8]={
    400.0f,440.0f,480.0f,520.0f,560.0f,600.0f,640.0f,680.0f
};
constant float3 crowPlumageLinearSRGBWeights[8]={
    float3(0.00171033f,-0.00251128f,0.02640591f),
    float3(0.08257090f,-0.09425744f,0.75526272f),
    float3(-0.08956674f,0.07761361f,0.34014497f),
    float3(-0.27795049f,0.49625930f,-0.02063986f),
    float3(0.13188385f,0.50129871f,-0.06735511f),
    float3(0.75319232f,0.06543094f,-0.02880139f),
    float3(0.37033621f,-0.04372594f,-0.00428158f),
    float3(0.02782362f,-0.00010791f,-0.00073564f)
};

inline float2 crowComplexMultiply(float2 first,float2 second) {
    return float2(
        first.x*second.x-first.y*second.y,
        first.x*second.y+first.y*second.x
    );
}

inline float2 crowComplexDivide(float2 numerator,float2 denominator) {
    float inverseMagnitude=1.0f/max(dot(denominator,denominator),1.0e-8f);
    return inverseMagnitude*float2(
        numerator.x*denominator.x+numerator.y*denominator.y,
        numerator.y*denominator.x-numerator.x*denominator.y
    );
}

inline float2 crowComplexSquareRoot(float2 value) {
    float magnitude=length(value);
    float realPart=sqrt(max(0.0f,0.5f*(magnitude+value.x)));
    float imaginaryMagnitude=sqrt(max(0.0f,0.5f*(magnitude-value.x)));
    float imaginaryPart=copysign(imaginaryMagnitude,value.y);
    return float2(realPart,imaginaryPart);
}

inline float2 crowForwardTransmittedCosine(
    float2 transmittedSine,
    float2 mediumIndex) {
    float2 transmittedCosine=crowComplexSquareRoot(
        float2(1.0f,0.0f)
            -crowComplexMultiply(transmittedSine,transmittedSine)
    );
    // Choose the square-root branch whose transmitted wave decays into an
    // absorbing medium rather than growing away from the interface.
    if(crowComplexMultiply(mediumIndex,transmittedCosine).y<0.0f){
        transmittedCosine=-transmittedCosine;
    }
    return transmittedCosine;
}

inline float2 crowComplexExponentialI(float2 phase) {
    float attenuation=exp(clamp(-phase.y,-80.0f,0.0f));
    return attenuation*float2(cos(phase.x),sin(phase.x));
}

inline float2 crowFresnelReflectionS(
    float2 incidentIndex,
    float2 transmittedIndex,
    float2 incidentCosine,
    float2 transmittedCosine) {
    float2 incidentAdmittance=crowComplexMultiply(
        incidentIndex,incidentCosine
    );
    float2 transmittedAdmittance=crowComplexMultiply(
        transmittedIndex,transmittedCosine
    );
    return crowComplexDivide(
        incidentAdmittance-transmittedAdmittance,
        incidentAdmittance+transmittedAdmittance
    );
}

inline float2 crowFresnelTransmissionS(
    float2 incidentIndex,
    float2 transmittedIndex,
    float2 incidentCosine,
    float2 transmittedCosine) {
    float2 incidentAdmittance=crowComplexMultiply(
        incidentIndex,incidentCosine
    );
    float2 transmittedAdmittance=crowComplexMultiply(
        transmittedIndex,transmittedCosine
    );
    return crowComplexDivide(
        2.0f*incidentAdmittance,
        incidentAdmittance+transmittedAdmittance
    );
}

inline float2 crowFresnelReflectionP(
    float2 incidentIndex,
    float2 transmittedIndex,
    float2 incidentCosine,
    float2 transmittedCosine) {
    float2 transmittedIncident=crowComplexMultiply(
        transmittedIndex,incidentCosine
    );
    float2 incidentTransmitted=crowComplexMultiply(
        incidentIndex,transmittedCosine
    );
    return crowComplexDivide(
        transmittedIncident-incidentTransmitted,
        transmittedIncident+incidentTransmitted
    );
}

inline float2 crowFresnelTransmissionP(
    float2 incidentIndex,
    float2 transmittedIndex,
    float2 incidentCosine,
    float2 transmittedCosine) {
    float2 denominator=crowComplexMultiply(
        transmittedIndex,incidentCosine
    )+crowComplexMultiply(incidentIndex,transmittedCosine);
    return crowComplexDivide(
        2.0f*crowComplexMultiply(incidentIndex,incidentCosine),
        denominator
    );
}

inline float2 crowAiryReflectionAmplitude(
    float2 directReflection,
    float2 directTransmission,
    float2 substrateReflection,
    float2 reverseTransmission,
    float2 roundTripPhase) {
    float2 internalReflection=crowComplexMultiply(
        crowComplexMultiply(
            crowComplexMultiply(directTransmission,substrateReflection),
            reverseTransmission
        ),
        roundTripPhase
    );
    float2 reverseReflection=-directReflection;
    float2 denominator=float2(1.0f,0.0f)-crowComplexMultiply(
        crowComplexMultiply(reverseReflection,substrateReflection),
        roundTripPhase
    );
    return directReflection+crowComplexDivide(
        internalReflection,denominator
    );
}

/// Per-light-path air/keratin/melanin Airy reflectance. Complex Snell angles,
/// s/p Fresnel amplitudes, and the complete internal-reflection series keep
/// the film response physical away from normal incidence. Positive imaginary
/// indices are extinction magnitudes, so the round trip decays in the cortex.
inline float2 crowThinFilmPolarizedReflectanceAtWavelength(
    float wavelengthNanometers,
    float cortexThicknessNanometers,
    float interfaceCosine,
    float4 complexIndices) {
    float2 airIndex=float2(1.0f,0.0f);
    float2 keratinIndex=complexIndices.xy;
    float2 melaninIndex=complexIndices.zw;
    float incidentCosine=max(saturate(interfaceCosine),1.0e-4f);
    float incidentSine=sqrt(max(0.0f,1.0f-incidentCosine*incidentCosine));
    float2 airCosine=float2(incidentCosine,0.0f);
    float2 keratinSine=crowComplexDivide(
        incidentSine*airIndex,keratinIndex
    );
    float2 melaninSine=crowComplexDivide(
        incidentSine*airIndex,melaninIndex
    );
    float2 keratinCosine=crowForwardTransmittedCosine(
        keratinSine,keratinIndex
    );
    float2 melaninCosine=crowForwardTransmittedCosine(
        melaninSine,melaninIndex
    );

    float2 airKeratinReflectionS=crowFresnelReflectionS(
        airIndex,keratinIndex,airCosine,keratinCosine
    );
    float2 airKeratinTransmissionS=crowFresnelTransmissionS(
        airIndex,keratinIndex,airCosine,keratinCosine
    );
    float2 keratinMelaninReflectionS=crowFresnelReflectionS(
        keratinIndex,melaninIndex,keratinCosine,melaninCosine
    );
    float2 airKeratinReflectionP=crowFresnelReflectionP(
        airIndex,keratinIndex,airCosine,keratinCosine
    );
    float2 airKeratinTransmissionP=crowFresnelTransmissionP(
        airIndex,keratinIndex,airCosine,keratinCosine
    );
    float2 keratinMelaninReflectionP=crowFresnelReflectionP(
        keratinIndex,melaninIndex,keratinCosine,melaninCosine
    );

    float2 reverseTransmissionRatio=crowComplexDivide(
        crowComplexMultiply(keratinIndex,keratinCosine),
        crowComplexMultiply(airIndex,airCosine)
    );
    float2 reverseTransmissionS=crowComplexMultiply(
        airKeratinTransmissionS,reverseTransmissionRatio
    );
    float2 reverseTransmissionP=crowComplexMultiply(
        airKeratinTransmissionP,reverseTransmissionRatio
    );
    float roundTripScale=4.0f*M_PI_F*cortexThicknessNanometers
        /wavelengthNanometers;
    float2 roundTripPhase=crowComplexExponentialI(
        roundTripScale*crowComplexMultiply(keratinIndex,keratinCosine)
    );
    float2 totalReflectionS=crowAiryReflectionAmplitude(
        airKeratinReflectionS,airKeratinTransmissionS,
        keratinMelaninReflectionS,reverseTransmissionS,roundTripPhase
    );
    float2 totalReflectionP=crowAiryReflectionAmplitude(
        airKeratinReflectionP,airKeratinTransmissionP,
        keratinMelaninReflectionP,reverseTransmissionP,roundTripPhase
    );
    return saturate(float2(
        dot(totalReflectionS,totalReflectionS),
        dot(totalReflectionP,totalReflectionP)
    ));
}

inline float crowThinFilmReflectanceAtWavelength(
    float wavelengthNanometers,
    float cortexThicknessNanometers,
    float interfaceCosine,
    float4 complexIndices) {
    float2 polarized=crowThinFilmPolarizedReflectanceAtWavelength(
        wavelengthNanometers,cortexThicknessNanometers,interfaceCosine,
        complexIndices
    );
    return 0.5f*(polarized.x+polarized.y);
}

kernel void probeCrowThinFilmOptics(
    device const float4* inputs [[buffer(0)]],
    constant float4& complexIndices [[buffer(1)]],
    device float4* outputs [[buffer(2)]],
    uint index [[thread_position_in_grid]]) {
    float4 input=inputs[index];
    float2 polarized=crowThinFilmPolarizedReflectanceAtWavelength(
        input.x,input.z,input.y,complexIndices
    );
    outputs[index]=float4(
        polarized,0.5f*(polarized.x+polarized.y),0.0f
    );
}

inline float crowGlossyBlackReflectanceAtWavelength(
    float wavelengthNanometers,
    float interfaceCosine,
    float melaninDensity,
    float cortexScale,
    float cortexThicknessNanometers,
    float4 plumageFilm,
    float4 plumageComplexIndices,
    float4 plumageMelanin,
    float4 plumageCortex) {
    float visiblePosition=saturate(
        (wavelengthNanometers-400.0f)*(1.0f/280.0f)
    );

    // The profile-owned keratin interface remains close to neutral before the
    // bounded thin-film term. Its directional term is dielectric Fresnel; the
    // anisotropic barb and barbule distributions remain responsible for where
    // that response is visible.
    float keratinIndex=plumageComplexIndices.x;
    float indexRatio=(keratinIndex-1.0f)/(keratinIndex+1.0f);
    float interfaceF0=indexRatio*indexRatio;
    float oneMinusCosine=1.0f-saturate(interfaceCosine);
    float dielectricInterfaceReflectance=interfaceF0
        +(1.0f-interfaceF0)*pow(oneMinusCosine,5.0f);
    float idealThinFilmReflectance=crowThinFilmReflectanceAtWavelength(
        wavelengthNanometers,cortexThicknessNanometers,interfaceCosine,
        plumageComplexIndices
    );
    float interfaceReflectance=mix(
        dielectricInterfaceReflectance,
        idealThinFilmReflectance,
        saturate(plumageFilm.z)
    );

    // Eumelanin is represented as broadband absorption rather than a painted
    // blue channel. The estimated extinction slope suppresses short-wave
    // volume return slightly more strongly; the exposed cortex remains the
    // dominant glossy-black signal.
    float melaninExtinction=mix(
        plumageMelanin.x,plumageMelanin.y,visiblePosition
    );
    float volumeReturn=plumageFilm.w
        *exp(-melaninDensity*melaninExtinction);
    float incoherentKeratinScatter=mix(
        plumageCortex.x,plumageCortex.y,visiblePosition
    );
    return cortexScale*interfaceReflectance
        +volumeReturn+incoherentKeratinScatter;
}

inline float3 crowGlossyBlackSpectrum(
    float interfaceCosine,
    float melaninDensity,
    float cortexScale,
    float cortexThicknessNanometers,
    float4 plumageFilm,
    float4 plumageComplexIndices,
    float4 plumageMelanin,
    float4 plumageCortex) {
    float3 linearRGB=float3(0.0f);
    for(uint sampleIndex=0u;sampleIndex<8u;++sampleIndex){
        float reflectance=crowGlossyBlackReflectanceAtWavelength(
            crowPlumageWavelengthNanometers[sampleIndex],
            interfaceCosine,
            melaninDensity,
            cortexScale,
            cortexThicknessNanometers,
            plumageFilm,
            plumageComplexIndices,
            plumageMelanin,
            plumageCortex
        );
        linearRGB+=reflectance*crowPlumageLinearSRGBWeights[sampleIndex];
    }
    return max(linearRGB,float3(0.0f));
}

/// Resolve the crossed hook-and-bow directions of interlocking barbules only
/// while their projected phase remains sampleable. Both waves converge to
/// zero at distance, so the unresolved vane retains its mean radiance rather
/// than turning into moire or a glittering screen-space noise field.
inline float2 crowInterlockingBarbuleSignal(
    float axial,
    float signedWidth,
    float identityPhase,
    float flightFeather) {
    float interior=smoothstep(0.075f,0.18f,axial)
        *(1.0f-smoothstep(0.86f,0.975f,axial))
        *(1.0f-smoothstep(0.70f,0.96f,abs(signedWidth)));
    float axialFrequency=mix(430.0f,610.0f,flightFeather);
    float transverseFrequency=mix(54.0f,82.0f,flightFeather);
    float hookPhase=axialFrequency*axial
        +transverseFrequency*signedWidth+identityPhase;
    float bowPhase=0.83f*axialFrequency*axial
        -1.12f*transverseFrequency*signedWidth+1.37f*identityPhase;
    float hook=crowBandLimitedSine(hookPhase);
    float bow=crowBandLimitedSine(bowPhase);
    float crossed=0.5f*(hook+bow)+0.25f*hook*bow;
    float separation=0.5f*abs(hook-bow);
    return interior*float2(crossed,separation);
}

/// Project the full diameter of an elliptical fiber cross section toward an
/// unnormalised 2D view direction. This is the closed-form full-ellipse case
/// of the projected-area expression used by Padrón-Griffe et al. (2024).
inline float crowProjectedEllipseDiameter(
    float2 direction,
    float2 axes) {
    float2 scaled=float2(axes.y*direction.x,axes.x*direction.y);
    return 2.0f*length(scaled);
}

inline float crowProjectedSegmentLength(float2 segment,float2 direction) {
    return abs(segment.x*direction.y-segment.y*direction.x);
}

// Constant-time 2D primitives for the differential projected-area mask in
// Padrón-Griffe et al. The discontinuity rays begin at ellipse tangencies,
// intersect the neighboring ellipse/barbule segments, and partition only the
// visible intervals. This is an MSL port of the authors' MIT masking model;
// it is not a sampled shadow approximation or explicit curve geometry.
inline float2 crowMaskEllipsePoint(
    float2 center,float2 axes,float parameter) {
    return center+axes*float2(cos(parameter),sin(parameter));
}

inline float crowMaskEllipseTangentParameter(float2 axes,float2 direction) {
    return atan2(-axes.y*direction.x,axes.x*direction.y);
}

inline float crowMaskEllipseParameterAt(
    float2 point,float2 center,float2 axes) {
    return atan2((point.y-center.y)/axes.y,(point.x-center.x)/axes.x);
}

inline float crowMaskEllipseProjectedArea(
    float2 axes,float2 direction,float first,float second) {
    return abs(
        direction.x*axes.y*(sin(first)-sin(second))
        +direction.y*axes.x*(cos(second)-cos(first))
    );
}

inline bool crowMaskEllipseRayNearestPositive(
    float2 origin,float2 direction,float2 center,float2 axes,
    thread float& nearest) {
    float2 scaledDirection=direction/axes;
    float2 scaledOffset=(origin-center)/axes;
    float a=dot(scaledDirection,scaledDirection);
    if(a<1.0e-12f){return false;}
    float b=2.0f*dot(scaledDirection,scaledOffset);
    float c=dot(scaledOffset,scaledOffset)-1.0f;
    float discriminant=b*b-4.0f*a*c;
    if(discriminant<0.0f){return false;}
    float root=sqrt(max(discriminant,0.0f));
    float inverse=0.5f/a;
    float first=(-b-root)*inverse;
    float second=(-b+root)*inverse;
    nearest=INFINITY;
    if(first>0.0f){nearest=first;}
    if(second>0.0f){nearest=min(nearest,second);}
    return isfinite(nearest);
}

inline float2 crowMaskSegmentNormal(float2 first,float2 second) {
    float2 perpendicular=float2(first.y-second.y,second.x-first.x);
    float magnitude=length(perpendicular);
    return magnitude>1.0e-12f
        ?perpendicular/magnitude
        :float2(0.0f,1.0f);
}

inline bool crowMaskSegmentRayUnbounded(
    float2 first,float2 second,float2 origin,float2 direction,
    thread float& rayParameter) {
    float2 normal=crowMaskSegmentNormal(first,second);
    float denominator=dot(normal,direction);
    if(abs(denominator)<1.0e-8f){return false;}
    rayParameter=dot(normal,first-origin)/denominator;
    return isfinite(rayParameter);
}

inline float crowMaskSegmentParameterAt(
    float2 first,float2 second,float2 point) {
    uint axis=abs(first.y-second.y)>abs(first.x-second.x)?1u:0u;
    float denominator=second[axis]-first[axis];
    if(abs(denominator)<1.0e-8f){return 0.0f;}
    return (2.0f*point[axis]-first[axis]-second[axis])/denominator;
}

inline bool crowMaskSegmentRayHit(
    float2 first,float2 second,float2 origin,float2 direction) {
    float rayParameter=0.0f;
    if(!crowMaskSegmentRayUnbounded(
        first,second,origin,direction,rayParameter
    )||rayParameter<=0.0f){return false;}
    float segmentParameter=crowMaskSegmentParameterAt(
        first,second,origin+rayParameter*direction
    );
    return segmentParameter>=-1.0f&&segmentParameter<=1.0f;
}

inline float crowMaskSegmentProjectedArea(
    float2 first,float2 second,float2 direction,
    float firstParameter,float secondParameter) {
    float2 firstPoint=mix(first,second,0.5f*(1.0f+firstParameter));
    float2 secondPoint=mix(first,second,0.5f*(1.0f+secondParameter));
    return length(secondPoint-firstPoint)
        *abs(dot(direction,crowMaskSegmentNormal(first,second)));
}

struct CrowBarbuleDiscontinuityMask {
    float transmission;
    float hMinimum;
    float hMaximum;
};

inline CrowBarbuleDiscontinuityMask crowExactBarbuleMask(
    float2 direction,float aspect,float separation) {
    float2 d=abs(direction);
    if(dot(d,d)<1.0e-10f){return {1.0f,-1.0f,1.0f};}
    float factor=1.0f/(2.0f+2.0f*max(separation,0.0f));
    float2 axes=float2(factor,factor*max(aspect,1.0f));
    float2 firstCenter=float2(0.0f);
    float2 secondCenter=float2(1.0f,0.0f);
    float2 separationFirst=float2(factor,0.0f);
    float2 separationSecond=float2(
        factor*(1.0f+2.0f*max(separation,0.0f)),0.0f
    );
    float tangent=crowMaskEllipseTangentParameter(axes,d);
    float thetaInitial=tangent-M_PI_F;
    float thetaEnd=thetaInitial+M_PI_F;
    float2 rayOrigin=crowMaskEllipsePoint(firstCenter,axes,thetaEnd);
    float totalBarbule=crowMaskEllipseProjectedArea(
        axes,d,thetaInitial,thetaEnd
    );
    float hit=0.0f;
    if(crowMaskEllipseRayNearestPositive(
        rayOrigin,d,secondCenter,axes,hit
    )) {
        float thetaShadow=crowMaskEllipseParameterAt(
            rayOrigin+hit*d,secondCenter,axes
        );
        if(thetaShadow>thetaEnd){thetaShadow-=2.0f*M_PI_F;}
        float shadow=crowMaskEllipseProjectedArea(
            axes,d,thetaInitial,thetaShadow
        );
        float hMinimum=2.0f*shadow/max(totalBarbule,1.0e-8f)-1.0f;
        return {0.0f,clamp(hMinimum,-1.0f,1.0f),1.0f};
    }

    float firstRayParameter=0.0f;
    float secondRayParameter=0.0f;
    float2 reverseOrigin=crowMaskEllipsePoint(
        secondCenter,axes,tangent+M_PI_F
    );
    bool firstValid=crowMaskSegmentRayUnbounded(
        separationFirst,separationSecond,rayOrigin,d,firstRayParameter
    );
    bool secondValid=crowMaskSegmentRayUnbounded(
        separationFirst,separationSecond,reverseOrigin,-d,secondRayParameter
    );
    if(!firstValid||!secondValid){return {1.0f,-1.0f,1.0f};}
    float separationArea=length(
        (rayOrigin+firstRayParameter*d)
        -(reverseOrigin-secondRayParameter*d)
    )*d.y;
    float transmission=separationArea
        /max(separationArea+totalBarbule,1.0e-8f);
    return {saturate(transmission),-1.0f,1.0f};
}

inline float crowExactBarbIntervalRate(
    float2 axes,float2 direction,float thetaMinimum,float thetaMaximum,
    float thetaInitial,float thetaEnd,float factor) {
    if(factor<=0.0f||thetaMinimum>=thetaMaximum){return 0.0f;}
    return factor*crowMaskEllipseProjectedArea(
        axes,direction,thetaMinimum,thetaMaximum
    );
}

inline float4 crowExactBarbMaskRates(
    float2 direction,float aspect,float inclination,float relativeLength,
    float firstTransparency,float secondTransparency) {
    float2 d=direction;
    float angle=inclination;
    if(d.y<0.0f){d.y=-d.y;angle=-angle;}
    bool flip=false;
    float leftTransparency=firstTransparency;
    float rightTransparency=secondTransparency;
    if(d.x<0.0f){
        d.x=-d.x;
        flip=true;
        float swapValue=leftTransparency;
        leftTransparency=rightTransparency;
        rightTransparency=swapValue;
    }
    if(dot(d,d)<1.0e-10f){return float4(0.0f,0.0f,0.0f,1.0f);}

    float lengthScale=max(relativeLength,1.0f);
    float factor=1.0f/(2.0f*(1.0f+lengthScale*cos(angle)));
    float2 axes=float2(factor,factor*max(aspect,1.0f));
    float2 firstCenter=float2(factor,0.0f);
    float2 secondCenter=float2(1.0f+factor,0.0f);
    float2 corner=float2(
        factor*(2.0f+lengthScale*cos(angle)),
        factor*lengthScale*sin(angle)
    );
    float2 rightFirst=float2(2.0f*factor,0.0f);
    float2 leftFirst=float2(1.0f,0.0f);
    float2 rightSecond=float2(1.0f+2.0f*factor,0.0f);
    float2 leftSecond=float2(2.0f,0.0f);
    float2 nextCorner=corner+float2(1.0f,0.0f);

    float thetaInitial=crowMaskEllipseTangentParameter(axes,d)-M_PI_F;
    float thetaEnd=thetaInitial+M_PI_F;
    float2 barbRayOrigin=crowMaskEllipsePoint(
        firstCenter,axes,thetaEnd
    );
    float2 barbuleRayOrigin=corner;
    float thetaHardShadow=thetaInitial;
    float thetaLeftShadow=-M_PI_F;
    float thetaRightShadow=thetaInitial;
    float hit=0.0f;
    if(crowMaskEllipseRayNearestPositive(
        barbRayOrigin,d,secondCenter,axes,hit
    )) {
        float theta=crowMaskEllipseParameterAt(
            barbRayOrigin+hit*d,secondCenter,axes
        );
        if(theta>thetaEnd){theta-=2.0f*M_PI_F;}
        thetaHardShadow=max(thetaHardShadow,theta);
    }
    if(crowMaskEllipseRayNearestPositive(
        barbuleRayOrigin,d,secondCenter,axes,hit
    )) {
        float theta=crowMaskEllipseParameterAt(
            barbuleRayOrigin+hit*d,secondCenter,axes
        );
        if(theta>thetaEnd){theta-=2.0f*M_PI_F;}
        thetaRightShadow=max(thetaRightShadow,theta);
    } else {
        float2 top=crowMaskEllipsePoint(
            secondCenter,axes,-0.5f*M_PI_F
        );
        if(corner.y<top.y){
            float2 other=top;
            other.y+=2.0f*(corner.y-top.y);
            if(crowMaskSegmentRayHit(top,other,barbuleRayOrigin,d)){
                thetaRightShadow=thetaEnd;
            }
        }
    }

    float barbRate=0.0f;
    if(thetaHardShadow<thetaLeftShadow
        &&thetaHardShadow<thetaRightShadow) {
        if(thetaLeftShadow<thetaRightShadow) {
            barbRate+=crowExactBarbIntervalRate(
                axes,d,thetaRightShadow,thetaEnd,thetaInitial,thetaEnd,1.0f
            );
            barbRate+=crowExactBarbIntervalRate(
                axes,d,thetaLeftShadow,thetaRightShadow,thetaInitial,thetaEnd,
                leftTransparency*rightTransparency
            );
            barbRate+=crowExactBarbIntervalRate(
                axes,d,thetaHardShadow,thetaLeftShadow,thetaInitial,thetaEnd,
                rightTransparency
            );
        } else {
            barbRate+=crowExactBarbIntervalRate(
                axes,d,thetaLeftShadow,thetaEnd,thetaInitial,thetaEnd,1.0f
            );
            barbRate+=crowExactBarbIntervalRate(
                axes,d,thetaRightShadow,thetaLeftShadow,thetaInitial,thetaEnd,
                leftTransparency
            );
            barbRate+=crowExactBarbIntervalRate(
                axes,d,thetaHardShadow,thetaRightShadow,thetaInitial,thetaEnd,
                rightTransparency
            );
        }
    } else if(thetaHardShadow<thetaLeftShadow) {
        barbRate+=crowExactBarbIntervalRate(
            axes,d,thetaLeftShadow,thetaEnd,thetaInitial,thetaEnd,1.0f
        );
        barbRate+=crowExactBarbIntervalRate(
            axes,d,thetaHardShadow,thetaLeftShadow,thetaInitial,thetaEnd,
            leftTransparency
        );
    } else if(thetaHardShadow<thetaRightShadow) {
        barbRate+=crowExactBarbIntervalRate(
            axes,d,thetaRightShadow,thetaEnd,thetaInitial,thetaEnd,1.0f
        );
        barbRate+=crowExactBarbIntervalRate(
            axes,d,thetaHardShadow,thetaRightShadow,thetaInitial,thetaEnd,
            leftTransparency*rightTransparency
        );
    } else {
        barbRate+=crowExactBarbIntervalRate(
            axes,d,thetaHardShadow,thetaEnd,thetaInitial,thetaEnd,1.0f
        );
    }

    float tRightMinimum=-1.0f;
    float tRightSelfShadowMinimum=-1.0f;
    float rayParameter=0.0f;
    if(!crowMaskSegmentRayUnbounded(
        rightFirst,corner,barbRayOrigin,d,rayParameter
    )||dot(d,crowMaskSegmentNormal(rightFirst,corner))<0.0f) {
        tRightMinimum=1.0f;
    } else {
        tRightMinimum=clamp(crowMaskSegmentParameterAt(
            rightFirst,corner,barbRayOrigin+rayParameter*d
        ),-1.0f,1.0f);
    }
    if(!crowMaskSegmentRayUnbounded(
        rightSecond,nextCorner,barbuleRayOrigin,d,rayParameter
    )) {
        tRightSelfShadowMinimum=1.0f;
    } else {
        tRightSelfShadowMinimum=clamp(crowMaskSegmentParameterAt(
            rightSecond,nextCorner,barbuleRayOrigin+rayParameter*d
        ),-1.0f,1.0f);
    }
    tRightSelfShadowMinimum=max(
        tRightSelfShadowMinimum,tRightMinimum
    );
    float rightRate=(1.0f-rightTransparency)
        *crowMaskSegmentProjectedArea(
            rightFirst,corner,d,tRightSelfShadowMinimum,1.0f
        );
    rightRate+=leftTransparency*rightTransparency
        *crowMaskSegmentProjectedArea(
            rightFirst,corner,d,tRightMinimum,tRightSelfShadowMinimum
        );

    float leftRate=0.0f;
    float tLeftTransparencyMaximum=1.0f;
    if(dot(d,crowMaskSegmentNormal(leftFirst,corner))<0.0f) {
        float tLeftMaximum=1.0f;
        if(!crowMaskSegmentRayUnbounded(
            leftFirst,corner,barbRayOrigin,d,rayParameter
        )) {
            tLeftMaximum=-1.0f;
        } else {
            tLeftMaximum=clamp(crowMaskSegmentParameterAt(
                leftFirst,corner,barbRayOrigin+rayParameter*d
            ),-1.0f,1.0f);
        }
        if(!crowMaskSegmentRayUnbounded(
            leftSecond,nextCorner,barbuleRayOrigin,d,rayParameter
        )) {
            tLeftTransparencyMaximum=-1.0f;
        } else {
            tLeftTransparencyMaximum=clamp(crowMaskSegmentParameterAt(
                leftSecond,nextCorner,barbuleRayOrigin+rayParameter*d
            ),-1.0f,1.0f);
        }
        tLeftTransparencyMaximum=min(
            tLeftTransparencyMaximum,tLeftMaximum
        );
        leftRate+=(1.0f-leftTransparency)
            *crowMaskSegmentProjectedArea(
                leftFirst,corner,d,-1.0f,tLeftTransparencyMaximum
            );
        leftRate+=leftTransparency*rightTransparency
            *crowMaskSegmentProjectedArea(
                leftFirst,corner,d,tLeftTransparencyMaximum,tLeftMaximum
            );
    } else {
        tLeftTransparencyMaximum=-1.0f;
        float tLeftMinimum=-1.0f;
        float tLeftTransparencyMinimum=-1.0f;
        if(!crowMaskSegmentRayUnbounded(
            leftFirst,corner,barbRayOrigin,d,rayParameter
        )) {
            tLeftMinimum=1.0f;
        } else {
            tLeftMinimum=clamp(crowMaskSegmentParameterAt(
                leftFirst,corner,barbRayOrigin+rayParameter*d
            ),-1.0f,1.0f);
        }
        if(!crowMaskSegmentRayUnbounded(
            leftSecond,nextCorner,barbuleRayOrigin,d,rayParameter
        )) {
            tLeftTransparencyMinimum=1.0f;
        } else {
            tLeftTransparencyMinimum=clamp(crowMaskSegmentParameterAt(
                leftSecond,nextCorner,barbuleRayOrigin+rayParameter*d
            ),-1.0f,1.0f);
        }
        tLeftTransparencyMinimum=max(
            tLeftTransparencyMinimum,tLeftMinimum
        );
        leftRate+=rightTransparency*(1.0f-leftTransparency)
            *crowMaskSegmentProjectedArea(
                leftFirst,corner,d,tLeftTransparencyMinimum,1.0f
            );
        leftRate+=rightTransparency*leftTransparency*rightTransparency
            *crowMaskSegmentProjectedArea(
                leftFirst,corner,d,tLeftMinimum,tLeftTransparencyMinimum
            );
    }

    float2 backOrigin=crowMaskEllipsePoint(
        secondCenter,axes,thetaInitial
    );
    float2 backDirection=-d;
    float transparencyRate=0.0f;
    if(crowMaskSegmentRayUnbounded(
        rightFirst,corner,backOrigin,backDirection,rayParameter
    )) {
        float maximum=clamp(crowMaskSegmentParameterAt(
            rightFirst,corner,backOrigin+rayParameter*backDirection
        ),-1.0f,1.0f);
        if(tRightSelfShadowMinimum<maximum) {
            transparencyRate+=rightTransparency
                *crowMaskSegmentProjectedArea(
                    rightFirst,corner,d,tRightSelfShadowMinimum,maximum
                );
        }
    }
    if(crowMaskSegmentRayUnbounded(
        leftFirst,corner,backOrigin,backDirection,rayParameter
    )) {
        float minimum=clamp(crowMaskSegmentParameterAt(
            leftFirst,corner,backOrigin+rayParameter*backDirection
        ),-1.0f,1.0f);
        if(minimum<tLeftTransparencyMaximum) {
            transparencyRate+=leftTransparency
                *crowMaskSegmentProjectedArea(
                    leftFirst,corner,d,minimum,tLeftTransparencyMaximum
                );
        }
    }

    if(flip){
        float swapValue=leftRate;
        leftRate=rightRate;
        rightRate=swapValue;
    }
    return max(
        float4(barbRate,leftRate,rightRate,transparencyRate),
        float4(0.0f)
    );
}

inline float4 crowExactBarbMask(
    float2 direction,float aspect,float inclination,float relativeLength,
    float firstTransparency,float secondTransparency) {
    float4 rates=crowExactBarbMaskRates(
        direction,aspect,inclination,relativeLength,
        firstTransparency,secondTransparency
    );
    float total=dot(rates,float4(1.0f));
    if(total<1.0e-8f){return float4(0.0f,0.0f,0.0f,1.0f);}
    return rates/total;
}

inline float4 crowExactFeatherVisibilityLocal(
    float3 viewDirection,float4 visibilityShape,float4 visibilityLayout) {
    float3 view=safeNormalizeCrow(
        viewDirection,float3(0.0f,1.0f,0.0f)
    );
    float azimuth=visibilityShape.z;
    float inclination=visibilityShape.w;
    float cosineAzimuth=cos(azimuth);
    float sineAzimuth=sin(azimuth);
    float cosineInclination=cos(inclination);
    float sineInclination=sin(inclination);
    float3 crossNormal=float3(0.0f,1.0f,0.0f);
    float3 proximalAxis=normalize(float3(
        -cosineInclination*sineAzimuth,
        sineInclination,
        cosineInclination*cosineAzimuth
    ));
    float3 distalAxis=normalize(float3(
        cosineInclination*sineAzimuth,
        sineInclination,
        cosineInclination*cosineAzimuth
    ));
    float3 proximalCross=safeNormalizeCrow(
        cross(crossNormal,proximalAxis),float3(1.0f,0.0f,0.0f)
    );
    float3 distalCross=safeNormalizeCrow(
        cross(crossNormal,distalAxis),float3(1.0f,0.0f,0.0f)
    );
    float3 proximalNormal=cross(proximalAxis,proximalCross);
    float3 distalNormal=cross(distalAxis,distalCross);
    // Match the reference implementation's inverse of its row-basis matrix.
    // Its first two returned components define the 2D barbule cross section.
    float3 proximalDirection3=proximalCross*view.x
        +proximalNormal*view.y+proximalAxis*view.z;
    float3 distalDirection3=distalCross*view.x
        +distalNormal*view.y+distalAxis*view.z;
    float2 proximalDirection=proximalDirection3.xy;
    float2 distalDirection=distalDirection3.xy;
    CrowBarbuleDiscontinuityMask proximal=crowExactBarbuleMask(
        proximalDirection,visibilityShape.y,visibilityLayout.y
    );
    CrowBarbuleDiscontinuityMask distal=crowExactBarbuleMask(
        distalDirection,visibilityShape.y,visibilityLayout.y
    );
    return crowExactBarbMask(
        view.xy,visibilityShape.x,inclination,visibilityLayout.x,
        proximal.transmission,distal.transmission
    );
}

/// Constant-cost far-field mixture for a regular pennaceous cross section.
/// The four normalized channels are barb, proximal barbule, distal barbule,
/// and transmission. Unlike the exact discontinuity-ray construction in the
/// cited model, this renderer approximation retains only projected ellipses,
/// projected barbule segments, and their local gap transmission. Parameters
/// are versioned estimates; explicit feather geometry remains authoritative.
inline float4 crowProjectedFeatherVisibilityApproximateLocal(
    float3 viewDirection,
    float4 visibilityShape,
    float4 visibilityLayout) {
    float3 view=safeNormalizeCrow(viewDirection,float3(0.0f,1.0f,0.0f));
    float barbAspect=max(visibilityShape.x,1.0f);
    float barbuleAspect=max(visibilityShape.y,1.0f);
    float azimuth=visibilityShape.z;
    float inclination=visibilityShape.w;
    float relativeLength=max(visibilityLayout.x,1.0f);
    float relativeSeparation=max(visibilityLayout.y,0.0f);

    float cosineAzimuth=cos(azimuth);
    float sineAzimuth=sin(azimuth);
    float cosineInclination=cos(inclination);
    float sineInclination=sin(inclination);
    float3 crossNormal=float3(0.0f,1.0f,0.0f);
    float3 proximalAxis=normalize(float3(
        -cosineInclination*sineAzimuth,
        sineInclination,
        cosineInclination*cosineAzimuth
    ));
    float3 distalAxis=normalize(float3(
        cosineInclination*sineAzimuth,
        sineInclination,
        cosineInclination*cosineAzimuth
    ));
    float3 proximalCross=safeNormalizeCrow(
        cross(crossNormal,proximalAxis),float3(1.0f,0.0f,0.0f)
    );
    float3 distalCross=safeNormalizeCrow(
        cross(crossNormal,distalAxis),float3(1.0f,0.0f,0.0f)
    );
    float3 proximalNormal=cross(proximalAxis,proximalCross);
    float3 distalNormal=cross(distalAxis,distalCross);

    float2 barbDirection=view.xy;
    float2 proximalDirection=float2(
        dot(view,proximalCross),dot(view,proximalNormal)
    );
    float2 distalDirection=float2(
        dot(view,distalCross),dot(view,distalNormal)
    );
    float barbArea=crowProjectedEllipseDiameter(
        barbDirection,float2(1.0f,barbAspect)
    );
    float proximalBarbuleArea=crowProjectedEllipseDiameter(
        proximalDirection,float2(1.0f,barbuleAspect)
    );
    float distalBarbuleArea=crowProjectedEllipseDiameter(
        distalDirection,float2(1.0f,barbuleAspect)
    );
    float proximalGap=relativeSeparation*abs(proximalDirection.y);
    float distalGap=relativeSeparation*abs(distalDirection.y);
    float proximalTransmission=proximalGap
        /max(proximalGap+proximalBarbuleArea,1.0e-6f);
    float distalTransmission=distalGap
        /max(distalGap+distalBarbuleArea,1.0e-6f);

    float2 proximalSegment=relativeLength*float2(
        -cosineInclination*sineAzimuth,sineInclination
    );
    float2 distalSegment=relativeLength*float2(
        cosineInclination*sineAzimuth,sineInclination
    );
    float proximalProjected=crowProjectedSegmentLength(
        proximalSegment,barbDirection
    );
    float distalProjected=crowProjectedSegmentLength(
        distalSegment,barbDirection
    );
    float4 areas=float4(
        barbArea,
        proximalProjected*(1.0f-proximalTransmission),
        distalProjected*(1.0f-distalTransmission),
        proximalProjected*proximalTransmission
            +distalProjected*distalTransmission
    );
    float total=max(areas.x+areas.y+areas.z+areas.w,1.0e-6f);
    return max(areas/total,float4(0.0f));
}

inline float4 crowProjectedFeatherVisibilityLocal(
    float3 viewDirection,float4 visibilityShape,float4 visibilityLayout) {
    float4 approximate=crowProjectedFeatherVisibilityApproximateLocal(
        viewDirection,visibilityShape,visibilityLayout
    );
    float exactStrength=saturate(visibilityLayout.w);
    if(exactStrength<=0.0f){return approximate;}
    float4 exact=crowExactFeatherVisibilityLocal(
        viewDirection,visibilityShape,visibilityLayout
    );
    float4 result=mix(approximate,exact,exactStrength);
    return max(result/max(dot(result,float4(1.0f)),1.0e-8f),float4(0.0f));
}

kernel void probeCrowProjectedFeatherVisibility(
    device const float4* directions [[buffer(0)]],
    constant float4& visibilityShape [[buffer(1)]],
    constant float4& visibilityLayout [[buffer(2)]],
    device float4* outputs [[buffer(3)]],
    uint index [[thread_position_in_grid]]) {
    outputs[index]=crowProjectedFeatherVisibilityLocal(
        directions[index].xyz,visibilityShape,visibilityLayout
    );
}

kernel void probeCrowAnalyticBarbuleMask(
    device const float4* directions [[buffer(0)]],
    constant float4& visibilityShape [[buffer(1)]],
    constant float4& visibilityLayout [[buffer(2)]],
    device float4* outputs [[buffer(3)]],
    uint index [[thread_position_in_grid]]) {
    CrowBarbuleDiscontinuityMask mask=crowExactBarbuleMask(
        directions[index].xy,visibilityShape.y,visibilityLayout.y
    );
    outputs[index]=float4(
        mask.transmission,mask.hMinimum,mask.hMaximum,0.0f
    );
}

kernel void probeCrowAnalyticBarbMaskRates(
    device const float4* directionsAndTransparency [[buffer(0)]],
    constant float4& visibilityShape [[buffer(1)]],
    constant float4& visibilityLayout [[buffer(2)]],
    device float4* outputs [[buffer(3)]],
    uint index [[thread_position_in_grid]]) {
    float4 input=directionsAndTransparency[index];
    outputs[index]=crowExactBarbMaskRates(
        input.xy,visibilityShape.x,visibilityShape.w,visibilityLayout.x,
        input.z,input.w
    );
}

inline uint crowResolvedCurveKind(uint4 identity) {
    // CPU surface triangles also reserve identity.x == UINT_MAX and their
    // material codes may equal the curve part codes. The explicit procedural
    // primitive namespace starts at 0x07100000, so require both domains.
    bool explicitPrimitive=identity.x==0xffffffffu
        &&identity.y>=0x07100000u;
    if(!explicitPrimitive){return 0u;}
    return identity.z==3u?1u:(identity.z==4u?2u:0u);
}

inline float3 showcaseCrowLinearRadiance(
    float3 world,
    float3 normalInput,
    float4 albedoAndMaterial,
    float3 eyePosition,
    float3 featherCoordinates,
    float3 resolvedCurveTangent,
    uint4 identity,
    float4 plumageFilm,
    float4 plumageComplexIndices,
    float4 plumageMelanin,
    float4 plumageCortex,
    float4 plumageVisibilityShape,
    float4 plumageVisibilityLayout) {
    float3 normal=normalize(normalInput);
    float3 view=normalize(eyePosition-world);
    float material=albedoAndMaterial.a;
    float3 key=normalize(float3(0.28f,-0.46f,0.84f));
    float3 fill=normalize(float3(-0.62f,0.34f,0.52f));
    float3 sun=normalize(float3(-0.74f,-0.34f,0.58f));
    float ndk=abs(dot(normal,key));
    float ndf=abs(dot(normal,fill));
    float nds=saturate(dot(normal,sun));
    float ndv=saturate(abs(dot(normal,view)));
    float rim=pow(1.0f-ndv,2.2f);
    float3 halfVector=normalize(key+view);
    float3 fillHalfVector=normalize(fill+view);
    float3 sunHalfVector=normalize(sun+view);

    // The standing presentation support is deliberately neutral and separate
    // from the bird material bands.
    if(material>0.90f){
        float diffuse=0.32f+0.58f*ndk+0.18f*ndf;
        float roughSpecular=pow(saturate(dot(normal,halfVector)),18.0f);
        float3 support=albedoAndMaterial.rgb*diffuse;
        support+=roughSpecular*float3(0.055f,0.060f,0.068f);
        return 1.18f*support;
    }

    // Eyes use the upper material band. A tight white catchlight and a warm
    // iris keep the eye readable without lifting the surrounding plumage.
    if(material>0.72f){
        float specular=pow(saturate(dot(normal,halfVector)),180.0f);
        float horizon=pow(1.0f-ndv,3.0f);
        float3 eyeRadiance=albedoAndMaterial.rgb*(0.13f+0.72f*ndk+0.12f*ndf);
        eyeRadiance+=float3(0.82f,0.76f,0.66f)*specular;
        eyeRadiance+=float3(0.055f,0.025f,0.010f)*horizon;
        return eyeRadiance;
    }

    // Keratin in the bill, claws, and legs is dark graphite rather than
    // feather black. It carries a broader, weaker highlight.
    if(material>0.48f){
        float specular=pow(saturate(dot(normal,halfVector)),48.0f);
        float3 keratin=albedoAndMaterial.rgb*(0.24f+0.66f*ndk+0.18f*ndf);
        keratin+=specular*float3(0.24f,0.27f,0.31f);
        keratin+=rim*float3(0.025f,0.035f,0.050f);
        return 1.12f*keratin;
    }

    // Eumelanin makes the body nearly black while the smooth cortex provides
    // a weak, view-dependent glossy return. Evaluate that return in eight
    // visible wavelength bands instead of choosing blue/violet RGB endpoints.
    // The feather-local density and cortex variation move with the vane.
    float grazing=pow(1.0f-ndv,1.55f);
    float flightFeather=smoothstep(0.19f,0.25f,material);
    float featherMaterial=1.0f-smoothstep(0.46f,0.50f,material);
    uint packedIdentity=identity.w;
    uint resolvedCurveKind=crowResolvedCurveKind(identity);
    float explicitBarbCurve=resolvedCurveKind==1u?1.0f:0.0f;
    float explicitBarbuleCurve=resolvedCurveKind==2u?1.0f:0.0f;
    float explicitCurve=max(explicitBarbCurve,explicitBarbuleCurve);
    float vaneCoordinates=step(1.0e-5f,
        abs(featherCoordinates.x)+abs(featherCoordinates.y));
    float persistentVane=featherMaterial*vaneCoordinates;
    // The far-field discontinuity mask is a surface substitute for unresolved
    // barb/barbule geometry. Once those fibers are explicit tubes, depth and
    // their resolved normal/tangent own visibility; applying the surface mask
    // again would double-occlude them.
    float surfaceVane=persistentVane*(1.0f-explicitCurve);
    float axial=saturate(featherCoordinates.x);
    float signedWidth=clamp(featherCoordinates.y,-1.0f,1.0f);
    float melaninIdentity=0.5f+0.5f*crowBandLimitedSine(
        1.91f*featherCoordinates.z+1.17f*axial+0.43f*abs(signedWidth)
    );
    float cortexIdentity=0.5f+0.5f*crowBandLimitedSine(
        2.47f*featherCoordinates.z+0.73f*axial-0.31f*signedWidth
    );
    float melaninDensity=mix(
        plumageMelanin.z,plumageMelanin.w,melaninIdentity
    );
    float cortexScale=mix(
        plumageCortex.z,plumageCortex.w,cortexIdentity
    );
    float thicknessIdentity=crowBandLimitedSine(
        1.37f*featherCoordinates.z+0.91f*axial+0.37f*signedWidth
    );
    float cortexThicknessNanometers=plumageFilm.x
        +plumageFilm.y*thicknessIdentity;
    float keyInterfaceCosine=saturate(abs(dot(view,halfVector)));
    float fillInterfaceCosine=saturate(abs(dot(view,fillHalfVector)));
    float sunInterfaceCosine=saturate(abs(dot(view,sunHalfVector)));
    float3 keySheen=crowGlossyBlackSpectrum(
        keyInterfaceCosine,melaninDensity,cortexScale,
        cortexThicknessNanometers,plumageFilm,plumageComplexIndices,
        plumageMelanin,plumageCortex
    );
    float3 fillSheen=crowGlossyBlackSpectrum(
        fillInterfaceCosine,melaninDensity,cortexScale,
        cortexThicknessNanometers,plumageFilm,plumageComplexIndices,
        plumageMelanin,plumageCortex
    );
    float3 sunSheen=crowGlossyBlackSpectrum(
        sunInterfaceCosine,melaninDensity,cortexScale,
        cortexThicknessNanometers,plumageFilm,plumageComplexIndices,
        plumageMelanin,plumageCortex
    );
    uint featherClass=packedIdentity&255u;
    float primaryVane=featherClass==1u?surfaceVane:0.0f;
    float secondaryVane=featherClass==2u?surfaceVane:0.0f;
    float rectrixVane=featherClass==3u?surfaceVane:0.0f;
    float underwingCovertVane=
        (featherClass==12u||featherClass==13u)?surfaceVane:0.0f;
    float greaterCovertVane=
        (featherClass==4u||featherClass==12u||featherClass==13u
            ||featherClass==14u||featherClass==15u)
            ?surfaceVane:0.0f;
    float dorsalBodyVane=featherClass==5u?surfaceVane:0.0f;
    float flankBodyVane=featherClass==6u?surfaceVane:0.0f;
    float ventralBodyVane=featherClass==7u?surfaceVane:0.0f;
    float throatBridgeVane=featherClass==17u?surfaceVane:0.0f;
    ventralBodyVane=max(ventralBodyVane,throatBridgeVane);
    float headNeckVane=featherClass==8u?surfaceVane:0.0f;
    float foreheadVane=featherClass==9u?surfaceVane:0.0f;
    float gularVane=featherClass==10u?surfaceVane:0.0f;
    float gularBridgeMaterialBlend=gularVane*saturate(
        (material-0.14f)/0.01f
    );
    float deepUnderplumageVane=featherClass==16u?surfaceVane:0.0f;
    float ventralFiberMaterial=featherClass==7u?explicitCurve:0.0f;
    float bodyContourVane=max(
        max(dorsalBodyVane,max(flankBodyVane,ventralBodyVane)),
        max(headNeckVane,max(foreheadVane,gularVane))
    );
    // American-crow dorsal body, tail, and wings form one optical region at
    // natural-viewing discrimination, so do not assign unrelated material
    // energy to those geometric classes. Ventral contour classes retain a
    // restrained step down without turning the body into a glossy black plate.
    float classSheenScale=1.0f;
    classSheenScale=mix(classSheenScale,0.72f,primaryVane);
    classSheenScale=mix(classSheenScale,0.72f,secondaryVane);
    classSheenScale=mix(classSheenScale,0.72f,rectrixVane);
    classSheenScale=mix(classSheenScale,0.72f,greaterCovertVane);
    classSheenScale=mix(classSheenScale,0.66f,underwingCovertVane);
    classSheenScale=mix(classSheenScale,0.72f,dorsalBodyVane);
    classSheenScale=mix(classSheenScale,0.60f,flankBodyVane);
    classSheenScale=mix(
        classSheenScale,0.62f,max(ventralBodyVane,ventralFiberMaterial)
    );
    classSheenScale=mix(classSheenScale,0.32f,throatBridgeVane);
    classSheenScale=mix(classSheenScale,0.60f,headNeckVane);
    classSheenScale=mix(classSheenScale,0.38f,foreheadVane);
    float gularBridgeOpticalBlend=gularBridgeMaterialBlend
        *smoothstep(0.35f,0.88f,axial);
    float gularSheenScale=mix(0.52f,0.25f,gularBridgeOpticalBlend);
    classSheenScale=mix(classSheenScale,gularSheenScale,gularVane);
    classSheenScale=mix(classSheenScale,0.12f,deepUnderplumageVane);
    float3 featherAxis=explicitCurve>0.5f
        ?safeNormalizeCrow(
            resolvedCurveTangent,float3(1.0f,0.0f,0.0f)
        )
        :crowFeatherAxis(world,normal,featherCoordinates.xy);
    // Short body feathers do not present one shared polished rachis direction.
    // Resolve two optical barb banks around a small, identity-stable tangent
    // turn. The phase is carried by the retained vane, so the microfacet field
    // follows the feather through standing motion and takeoff instead of
    // swimming in world space. Geometry and silhouette ownership stay exact.
    float bodyOpticalIdentity=crowBandLimitedSine(
        1.63f*featherCoordinates.z+0.41f*float(featherClass)
    );
    float bodyOpticalDrift=crowBandLimitedSine(
        2.17f*featherCoordinates.z+1.31f*axial
            +0.29f*float(featherClass)
    );
    float bodyOpticalTurn=bodyContourVane
        *(0.105f*bodyOpticalIdentity+0.035f*bodyOpticalDrift);
    float3 featherBarbAxis=safeNormalizeCrow(
        cross(normal,featherAxis),float3(0.0f,1.0f,0.0f)
    );
    float3 barbCrossAxis=safeNormalizeCrow(
        cross(normal,featherBarbAxis),featherAxis
    );
    float3 viewInBarbFrame=float3(
        dot(view,barbCrossAxis),
        dot(view,normal),
        dot(view,featherBarbAxis)
    );
    float4 projectedVisibility=crowProjectedFeatherVisibilityLocal(
        viewInBarbFrame,plumageVisibilityShape,plumageVisibilityLayout
    );
    float projectedVisibilityStrength=
        saturate(plumageVisibilityLayout.z)*surfaceVane;
    float opaqueProjectedVisibility=max(
        projectedVisibility.x+projectedVisibility.y+projectedVisibility.z,
        1.0e-5f
    );
    float normalizedBarbVisibility=
        projectedVisibility.x/opaqueProjectedVisibility;
    float normalizedBarbuleVisibility=
        (projectedVisibility.y+projectedVisibility.z)
            /opaqueProjectedVisibility;
    float visibilityEnergy=mix(
        1.0f,
        projectedVisibility.x
            +0.92f*(projectedVisibility.y+projectedVisibility.z),
        projectedVisibilityStrength
    );
    float barbVisibility=mix(
        1.0f,0.78f+0.44f*normalizedBarbVisibility,
        projectedVisibilityStrength
    );
    float barbuleVisibility=mix(
        1.0f,0.78f+0.44f*normalizedBarbuleVisibility,
        projectedVisibilityStrength
    );
    float3 bodyOpticalAxis=safeNormalizeCrow(
        featherAxis*cos(bodyOpticalTurn)
            +featherBarbAxis*sin(bodyOpticalTurn),
        featherAxis
    );
    float bankIdentity=0.5f+0.5f*crowBandLimitedSine(
        2.39f*featherCoordinates.z+0.67f*float(featherClass)
    );
    float bodyBankSpread=bodyContourVane*(0.075f+0.095f*bankIdentity);
    float3 opticalBarbAxis=safeNormalizeCrow(
        cross(normal,bodyOpticalAxis),featherBarbAxis
    );
    float3 firstBodyBank=safeNormalizeCrow(
        bodyOpticalAxis*cos(bodyBankSpread)
            +opticalBarbAxis*sin(bodyBankSpread),
        bodyOpticalAxis
    );
    float3 secondBodyBank=safeNormalizeCrow(
        bodyOpticalAxis*cos(bodyBankSpread)
            -opticalBarbAxis*sin(bodyBankSpread),
        bodyOpticalAxis
    );
    float vaneAnisotropy=mix(
        0.18f,
        mix(0.52f,1.0f,flightFeather),
        vaneCoordinates
    );
    vaneAnisotropy=mix(vaneAnisotropy,0.519f,dorsalBodyVane);
    vaneAnisotropy=mix(vaneAnisotropy,0.50f,flankBodyVane);
    vaneAnisotropy=mix(vaneAnisotropy,0.48f,ventralBodyVane);
    vaneAnisotropy=mix(vaneAnisotropy,0.40f,headNeckVane);
    vaneAnisotropy=mix(vaneAnisotropy,0.32f,foreheadVane);
    vaneAnisotropy=mix(vaneAnisotropy,0.36f,gularVane);
    vaneAnisotropy=mix(vaneAnisotropy,0.58f,underwingCovertVane);
    float longitudinalRoughness=mix(0.34f,0.25f,flightFeather);
    float transverseRoughness=mix(0.12f,0.075f,flightFeather);
    longitudinalRoughness=mix(longitudinalRoughness,0.215f,primaryVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.285f,secondaryVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.245f,rectrixVane);
    transverseRoughness=mix(transverseRoughness,0.065f,primaryVane);
    transverseRoughness=mix(transverseRoughness,0.090f,secondaryVane);
    transverseRoughness=mix(transverseRoughness,0.075f,rectrixVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.333f,dorsalBodyVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.385f,flankBodyVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.350f,ventralBodyVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.360f,headNeckVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.390f,foreheadVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.370f,gularVane);
    transverseRoughness=mix(transverseRoughness,0.142f,dorsalBodyVane);
    transverseRoughness=mix(transverseRoughness,0.185f,flankBodyVane);
    transverseRoughness=mix(transverseRoughness,0.154f,ventralBodyVane);
    transverseRoughness=mix(transverseRoughness,0.156f,headNeckVane);
    transverseRoughness=mix(transverseRoughness,0.165f,foreheadVane);
    transverseRoughness=mix(transverseRoughness,0.160f,gularVane);
    longitudinalRoughness=mix(
        longitudinalRoughness,0.325f,underwingCovertVane
    );
    transverseRoughness=mix(
        transverseRoughness,0.105f,underwingCovertVane
    );
    // Stable per-feather barb-bank orientation also carries a bounded
    // microfacet-width variation. This prevents thousands of short body vanes
    // from sharing one manufactured highlight band while remaining attached
    // to the retained local feather coordinates through motion and takeoff.
    longitudinalRoughness*=1.0f+0.10f*bodyContourVane*bodyOpticalIdentity;
    transverseRoughness*=1.0f+0.12f*bodyContourVane*bodyOpticalDrift;
    float genericKeyAnisotropicSpecular=crowFeatherAnisotropicLobe(
        normal,featherAxis,halfVector,
        longitudinalRoughness,transverseRoughness
    );
    float bodyBankKeyAnisotropicSpecular=0.5f*(
        crowFeatherAnisotropicLobe(
            normal,firstBodyBank,halfVector,
            longitudinalRoughness,transverseRoughness
        )
        +crowFeatherAnisotropicLobe(
            normal,secondBodyBank,halfVector,
            longitudinalRoughness,transverseRoughness
        )
    );
    float genericFillAnisotropicSpecular=crowFeatherAnisotropicLobe(
        normal,featherAxis,fillHalfVector,
        longitudinalRoughness,transverseRoughness
    );
    float bodyBankFillAnisotropicSpecular=0.5f*(
        crowFeatherAnisotropicLobe(
            normal,firstBodyBank,fillHalfVector,
            longitudinalRoughness,transverseRoughness
        )
        +crowFeatherAnisotropicLobe(
            normal,secondBodyBank,fillHalfVector,
            longitudinalRoughness,transverseRoughness
        )
    );
    float genericSunAnisotropicSpecular=crowFeatherAnisotropicLobe(
        normal,featherAxis,sunHalfVector,
        longitudinalRoughness,transverseRoughness
    );
    float bodyBankSunAnisotropicSpecular=0.5f*(
        crowFeatherAnisotropicLobe(
            normal,firstBodyBank,sunHalfVector,
            longitudinalRoughness,transverseRoughness
        )
        +crowFeatherAnisotropicLobe(
            normal,secondBodyBank,sunHalfVector,
            longitudinalRoughness,transverseRoughness
        )
    );
    float keyAnisotropicSpecular=mix(
        genericKeyAnisotropicSpecular,
        bodyBankKeyAnisotropicSpecular,
        bodyContourVane
    );
    float fillAnisotropicSpecular=mix(
        genericFillAnisotropicSpecular,
        bodyBankFillAnisotropicSpecular,
        bodyContourVane
    );
    float sunAnisotropicSpecular=mix(
        genericSunAnisotropicSpecular,
        bodyBankSunAnisotropicSpecular,
        bodyContourVane
    );
    float anisotropicSpecular=featherMaterial*vaneAnisotropy*(
        0.78f*keyAnisotropicSpecular
            +0.14f*fillAnisotropicSpecular
            +0.08f*sunAnisotropicSpecular
    );
    float genericRachisAxial=smoothstep(0.035f,0.16f,axial)
        *(1.0f-smoothstep(0.80f,0.985f,axial));
    float bodyRachisAxial=smoothstep(0.48f,0.60f,axial)
        *(1.0f-smoothstep(0.82f,0.94f,axial));
    float bodyRachisIdentity=0.5f+0.5f*crowBandLimitedSine(
        1.73f*featherCoordinates.z+0.31f*float(featherClass)
    );
    float bodyRachisResolution=crowScreenResolvedTransverseFeatureVisibility(
        signedWidth,
        crowBodyRachisFadeStartPixels,
        crowBodyRachisFadeEndPixels
    );
    float bodyRachisScale=(0.16f+0.18f*bodyRachisIdentity)
        *bodyRachisResolution;
    float rachis=surfaceVane*(1.0f-greaterCovertVane)
        *mix(genericRachisAxial,bodyRachisAxial,bodyContourVane)
        *mix(1.0f,bodyRachisScale,bodyContourVane)
        *exp2(-42.0f*abs(signedWidth));
    // Greater coverts are long enough to expose a seated shaft but too short
    // for a bright remex-style rachis. Resolve a narrow central core, broader
    // shoulder, and shallow lateral groove entirely inside the owning vane.
    // This improves close-up structure without adding geometry that can alter
    // the proven body-wing silhouette at grazing angles.
    float greaterCovertRachisEnvelope=greaterCovertVane
        *smoothstep(0.060f,0.16f,axial)
        *(1.0f-smoothstep(0.76f,0.95f,axial));
    float greaterCovertRachisCore=greaterCovertRachisEnvelope
        *exp2(-118.0f*abs(signedWidth));
    float greaterCovertRachisShoulder=greaterCovertRachisEnvelope
        *exp2(-46.0f*abs(signedWidth));
    float greaterCovertRachisGroove=greaterCovertRachisEnvelope
        *max(
            exp2(-24.0f*abs(signedWidth))
                -exp2(-72.0f*abs(signedWidth)),
            0.0f
        );
    float barbFrequency=178.0f;
    barbFrequency=mix(barbFrequency,214.0f,primaryVane);
    barbFrequency=mix(barbFrequency,190.0f,secondaryVane);
    barbFrequency=mix(barbFrequency,186.0f,greaterCovertVane);
    barbFrequency=mix(barbFrequency,180.0f,dorsalBodyVane);
    barbFrequency=mix(barbFrequency,176.0f,flankBodyVane);
    barbFrequency=mix(barbFrequency,172.0f,ventralBodyVane);
    barbFrequency=mix(barbFrequency,176.0f,headNeckVane);
    barbFrequency=mix(barbFrequency,170.0f,foreheadVane);
    barbFrequency=mix(barbFrequency,168.0f,gularVane);
    float localBarbAngle=
        barbFrequency*axial+23.0f*abs(signedWidth)+7.0f*signedWidth
            +featherCoordinates.z;
    float localBarbWave=crowBandLimitedSine(localBarbAngle);
    float localBarbs=0.5f+0.5f*localBarbWave;
    float2 interlockingBarbules=crowInterlockingBarbuleSignal(
        axial,signedWidth,featherCoordinates.z,
        max(flightFeather,0.55f*greaterCovertVane)
    )*surfaceVane;
    float barbPhase=520.0f*world.x+390.0f*world.y-270.0f*world.z;
    float barb=0.5f+0.5f*crowBandLimitedSine(barbPhase);
    float barbSignal=mix(barb,localBarbs,surfaceVane);
    float barbMicro=surfaceVane
        *mix(0.006f+0.010f*barbSignal,0.010f+0.018f*barbSignal,flightFeather)
        *grazing*mix(0.25f,1.0f,flightFeather);
    float vaneEdge=surfaceVane*smoothstep(0.78f,0.98f,abs(signedWidth))
        *mix(0.35f,1.0f,flightFeather);
    // Body vane barbs are not a single polished plate. Tilt only the specular
    // sample across the resolved barb direction, using the stable per-feather
    // phase carried by the procedural vane. Body contours keep a bounded
    // 1.4-degree normal perturbation; flight-feather barbules remain unchanged.
    float3 bodyBarbAxis=safeNormalizeCrow(
        cross(normal,bodyOpticalAxis),float3(0.0f,1.0f,0.0f)
    );
    float bodyBarbTilt=0.024f*bodyContourVane*localBarbWave
        *(1.0f-smoothstep(0.72f,0.96f,abs(signedWidth)));
    float bodyIdentityTilt=bodyContourVane
        *(0.045f*bodyOpticalIdentity+0.015f*bodyOpticalDrift);
    float bodyAxialTilt=0.022f*bodyContourVane*bodyOpticalDrift;
    float barbuleTilt=mix(0.006f,0.014f,flightFeather)
        *interlockingBarbules.x;
    float3 specularNormal=safeNormalizeCrow(
        normal+(bodyBarbTilt+bodyIdentityTilt+barbuleTilt)*bodyBarbAxis
            +(bodyAxialTilt+0.45f*barbuleTilt)*featherAxis,
        normal
    );
    // Overlapping body contours form a broader collective cortex response at
    // whole-bird distance. Preserve the tight exponent on exposed flight
    // feathers while preventing every body vane from becoming a silver rib.
    float sharpExponent=mix(92.0f,44.0f,bodyContourVane);
    float featherSpecular=
        0.78f*pow(saturate(dot(specularNormal,halfVector)),sharpExponent)
        +0.14f*pow(saturate(dot(specularNormal,fillHalfVector)),sharpExponent)
        +0.08f*pow(saturate(dot(specularNormal,sunHalfVector)),sharpExponent);
    float softSpecular=
        0.78f*pow(saturate(dot(normal,halfVector)),24.0f)
        +0.14f*pow(saturate(dot(normal,fillHalfVector)),24.0f)
        +0.08f*pow(saturate(dot(normal,sunHalfVector)),24.0f);
    float diffuse=0.28f+0.62f*ndk+0.16f*ndf+0.10f*nds;
    float flightDarkening=mix(1.0f,0.58f,flightFeather);
    float3 color=albedoAndMaterial.rgb*diffuse*flightDarkening;
    color*=visibilityEnergy;
    color*=mix(1.0f,0.82f,foreheadVane);
    float3 pathSheen=
        keySheen*(0.31f+0.50f*ndk)
        +fillSheen*(0.10f*ndf)
        +sunSheen*(0.09f*nds);
    float3 meanSheen=
        0.78f*keySheen+0.14f*fillSheen+0.08f*sunSheen;
    color+=pathSheen*(0.022f+0.125f*grazing)
        *flightDarkening*(0.72f+0.28f*anisotropicSpecular)
        *classSheenScale*visibilityEnergy;
    color+=barbMicro*barbVisibility*classSheenScale
        *mix(float3(0.035f,0.070f,0.11f),meanSheen,0.45f);
    color+=interlockingBarbules.y*barbuleVisibility*grazing*classSheenScale
        *mix(float3(0.0025f,0.0055f,0.0090f),meanSheen,0.28f);
    float3 sharpTint=mix(
        float3(0.075f,0.095f,0.125f),
        float3(0.030f,0.038f,0.050f),
        flightFeather
    );
    float3 softTint=mix(
        float3(0.014f,0.021f,0.034f),
        float3(0.006f,0.009f,0.014f),
        flightFeather
    );
    // Body contour vanes are short, overlapping, and collectively rougher
    // than exposed remiges. Keep their sharp lobe below the isolated silver
    // flashes that otherwise appear when one shoulder vane meets the half
    // vector, while preserving the full sharp response on flight feathers.
    float classSharpScale=1.0f;
    classSharpScale=mix(classSharpScale,0.82f,primaryVane);
    classSharpScale=mix(classSharpScale,0.60f,secondaryVane);
    classSharpScale=mix(classSharpScale,0.72f,rectrixVane);
    classSharpScale=mix(classSharpScale,0.48f,greaterCovertVane);
    classSharpScale=mix(classSharpScale,0.42f,underwingCovertVane);
    classSharpScale=mix(classSharpScale,0.32f,dorsalBodyVane);
    classSharpScale=mix(classSharpScale,0.30f,flankBodyVane);
    classSharpScale=mix(
        classSharpScale,0.28f,max(ventralBodyVane,ventralFiberMaterial)
    );
    classSharpScale=mix(classSharpScale,0.14f,throatBridgeVane);
    classSharpScale=mix(classSharpScale,0.28f,headNeckVane);
    classSharpScale=mix(classSharpScale,0.20f,foreheadVane);
    classSharpScale=mix(classSharpScale,0.24f,gularVane);
    classSharpScale=mix(classSharpScale,0.08f,deepUnderplumageVane);
    color+=sharpTint*featherSpecular*mix(0.30f,1.0f,flightFeather)
        *classSharpScale;
    color+=softTint*softSpecular;
    float classAnisotropicScale=mix(1.0f,0.40f,bodyContourVane)
        *mix(1.0f,0.50f,throatBridgeVane)
        *mix(1.0f,0.12f,deepUnderplumageVane);
    color+=classAnisotropicScale*anisotropicSpecular
        *mix(float3(0.020f,0.030f,0.046f),float3(0.012f,0.020f,0.034f),flightFeather);
    color*=1.0f-0.055f*surfaceVane*(1.0f-localBarbs);
    color+=rachis*mix(0.20f,1.0f,flightFeather)
        *(0.012f+0.025f*ndk)*float3(0.42f,0.56f,0.74f);
    color*=1.0f-0.022f*greaterCovertRachisGroove;
    color+=greaterCovertRachisShoulder*(0.004f+0.010f*ndk)
        *float3(0.24f,0.34f,0.48f);
    color+=greaterCovertRachisCore*(0.006f+0.016f*ndk)
        *float3(0.38f,0.50f,0.68f);
    color+=vaneEdge*grazing*classSheenScale
        *float3(0.010f,0.022f,0.042f);
    // Adult crow plumage should remain neutral-black under the warm key. A
    // direct copper lobe overwhelms the very low eumelanin albedo and makes
    // broad body regions read brown, so only a restrained cool sky return is
    // added here; weak film structure stays view-dependent in `sheen`.
    color+=nds*float3(0.004f,0.006f,0.010f);
    color+=rim*mix(1.0f,classSheenScale,max(surfaceVane,explicitCurve))
        *float3(0.022f,0.040f,0.065f);
    // This analytic lobe stands in only for shadowed feather volume inside the
    // folded wing-tail junction. Suppress exposed-cortex energy so a grazing
    // rear camera cannot turn the hidden gap fill into a glossy capsule.
    color*=mix(1.0f,0.30f,deepUnderplumageVane);
    return 1.68f*color;
}

/// GPU contract for the body-rachis optical LOD. The fragment path supplies a
/// derivative-derived span; this probe locks the threshold response itself.
kernel void probeCrowBodyRachisOpticalLOD(
    device const float* projectedSpanPixels [[buffer(0)]],
    device float* visibility [[buffer(1)]],
    uint index [[thread_position_in_grid]]) {
    visibility[index]=crowResolvedTransverseFeatureVisibility(
        projectedSpanPixels[index],
        crowBodyRachisFadeStartPixels,
        crowBodyRachisFadeEndPixels
    );
}

/// Executable contract for the resolved-curve material boundary. Surface vanes
/// respond to the far-field discontinuity mask; explicit fibers do not, and
/// instead respond to their retained geometric tangent.
kernel void probeCrowResolvedCurveVisibility(
    device float4* outputs [[buffer(0)]],
    uint index [[thread_position_in_grid]]) {
    if(index>=5u){return;}
    uint4 identity=index<3u
        ?uint4(0xffffffffu,0x07100001u,3u,7u)
        :uint4(0xffffffffu,17u,3u,7u);
    bool explicitCurve=crowResolvedCurveKind(identity)!=0u;
    bool disableAnalyticMask=index==1u||index==4u;
    float3 tangent=index==2u
        ?normalize(float3(0.15f,0.92f,0.36f))
        :normalize(float3(0.94f,0.18f,0.29f));
    float4 visibilityShape=float4(
        2.4f,3.2f,0.78539816f,0.31415927f
    );
    float4 visibilityLayout=float4(
        5.0f,0.55f,0.62f,disableAnalyticMask?0.0f:1.0f
    );
    float4 projected=crowProjectedFeatherVisibilityLocal(
        normalize(float3(0.37f,0.81f,0.45f)),
        visibilityShape,visibilityLayout
    );
    float strength=visibilityLayout.z*(explicitCurve?0.0f:1.0f);
    float energy=mix(
        1.0f,
        projected.x+0.92f*(projected.y+projected.z),
        strength
    );
    float lobe=crowFeatherAnisotropicLobe(
        normalize(float3(0.24f,-0.31f,0.92f)),
        tangent,
        normalize(float3(0.44f,-0.19f,0.88f)),
        0.34f,0.12f
    );
    outputs[index]=float4(energy,lobe,strength,1.0f);
}

fragment float4 showcaseCrowFragment(
    RasterVertex in [[stage_in]],
    constant CameraUniforms& camera [[buffer(0)]]) {
    float3 radiance=showcaseCrowLinearRadiance(
        in.world,in.normal,in.color,camera.eyeAndWidth.xyz,float3(in.uv,0),
        float3(0.0f),uint4(0u),
        float4(160.0f,18.0f,0.08f,0.016f),
        float4(1.56f,0.03f,2.00f,0.60f),
        float4(1.32f,0.88f,1.62f,1.84f),
        float4(0.00492f,0.006f,0.92f,1.04f),
        float4(2.4f,3.2f,0.78539816f,0.31415927f),
        float4(5.0f,0.55f,0.62f,0.0f)
    );
    return float4(1.0f-exp(-radiance),1.0f);
}

fragment CrowAOVOutput showcaseCrowAOVFragment(
    CrowRasterVertex in [[stage_in]],
    constant CrowTemporalCameraUniforms& camera [[buffer(0)]]) {
    float3 normal=in.normal;
    float3 radiance=showcaseCrowLinearRadiance(
        in.world,normal,in.albedoAndMaterial,camera.eyeAndWidth.xyz,
        in.featherCoordinates,in.resolvedCurveTangent,in.identity,
        camera.plumageFilm,camera.plumageComplexIndices,
        camera.plumageMelanin,camera.plumageCortex,
        camera.plumageVisibilityShape,camera.plumageVisibilityLayout
    );
    float inversePreviousW=1.0f/in.previousClipPosition.w;
    float2 previousNDC=in.previousClipPosition.xy*inversePreviousW;
    float2 previousPixel=(previousNDC*float2(0.5f,-0.5f)+0.5f)
        *camera.viewportAndInverse.xy;
    float2 motion=camera.viewportAndInverse.z>0.5f
        ? float2(0)
        : previousPixel-in.position.xy;
    CrowAOVOutput out;
    out.beauty=half4(half3(radiance),half(1));
    out.albedoAndMaterial=half4(in.albedoAndMaterial);
    // Keep material classification in albedo.w. normal.w is geometric sample
    // coverage so resolved edge normals and depth are never mistaken for
    // fully-covered surface samples by temporal or dataset consumers.
    out.normal=half4(half3(normal),half(1));
    out.motion=half2(motion);
    out.metricDepth=length(camera.eyeAndWidth.xyz-in.world);
    return out;
}

fragment uint4 showcaseCrowIdentityFragment(
    CrowRasterVertex in [[stage_in]]) {
    return in.identity;
}

fragment float4 showcaseWireFragment(RasterVertex in [[stage_in]]) {
    float intensity=0.025f+0.055f*clamp(in.color.g+in.color.b,0.0f,1.0f);
    return float4(0.48f,0.88f,1.0f,intensity);
}

vertex RasterVertex showcaseBackgroundVertex(uint vid [[vertex_id]]) {
    float2 positions[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};
    RasterVertex out;
    out.position=float4(positions[vid],0.999f,1);
    out.world=float3(0);out.normal=float3(0,0,1);out.color=float4(1);
    out.uv=0.5f*(positions[vid]+1.0f);
    return out;
}

fragment float4 showcaseBackgroundFragment(
    RasterVertex in [[stage_in]],
    constant float4& options [[buffer(0)]]) {
    float2 uv=in.uv;
    float2 centered=uv-0.5f;
    centered.x*=options.y;
    float radial=length(centered);
    float glow=exp(-4.8f*dot(centered-float2(-0.12f,0.02f),centered-float2(-0.12f,0.02f)));
    float horizon=exp(-68.0f*(uv.y-0.43f)*(uv.y-0.43f));
    float pulse=0.5f+0.5f*cos(6.2831853f*options.x);
    float gridX=smoothstep(0.990f,1.0f,cos(94.0f*centered.x));
    float gridY=smoothstep(0.990f,1.0f,cos(94.0f*(uv.y-0.43f)));
    float grid=(gridX+gridY)*horizon*0.032f;
    float vignette=1.0f-smoothstep(0.20f,0.92f,radial);
    float3 base=mix(float3(0.002f,0.007f,0.019f),float3(0.014f,0.048f,0.088f),uv.y);
    base+=glow*float3(0.018f,0.070f,0.105f);
    base+=horizon*(0.014f+0.004f*pulse)*float3(0.10f,0.46f,0.70f);
    base+=grid*float3(0.16f,0.58f,0.82f);
    base*=0.72f+0.28f*vignette;
    return float4(base,1);
}

inline float3 showcaseCrowBackgroundRadiance(
    float2 uv,
    float4 options) {
    float aspect=max(options.y,0.1f);
    float2 p=uv-0.5f;
    p.x*=aspect;
    float horizon=smoothstep(0.18f,0.68f,uv.y);
    float3 low=float3(0.012f,0.022f,0.038f);
    float3 high=float3(0.055f,0.115f,0.205f);
    float3 sky=mix(low,high,horizon);
    float2 sunCenter=float2(-0.46f*aspect,0.22f);
    float sun=exp(-13.0f*dot(p-sunCenter,p-sunCenter));
    float halo=exp(-2.8f*dot(p-sunCenter,p-sunCenter));
    sky+=sun*float3(1.42f,0.78f,0.34f)+halo*float3(0.13f,0.075f,0.045f);
    float cloudA=sin(5.2f*p.x+0.7f*sin(9.0f*p.y));
    float cloudB=sin(8.5f*p.x-3.7f*p.y+1.1f);
    float cloud=smoothstep(0.72f,1.45f,cloudA+0.52f*cloudB);
    sky+=cloud*(0.020f+0.022f*sun)*float3(0.60f,0.72f,0.82f);
    float vignette=1.0f-smoothstep(0.42f,1.02f,length(p));
    sky*=0.66f+0.34f*vignette;
    float grain=fract(sin(dot(floor(uv*float2(1280.0f,720.0f)),float2(12.9898f,78.233f)))*43758.5453f);
    sky+=(grain-0.5f)/420.0f;
    return sky;
}

fragment float4 showcaseCrowBackgroundFragment(
    RasterVertex in [[stage_in]],
    constant float4& options [[buffer(0)]]) {
    return float4(showcaseCrowBackgroundRadiance(in.uv,options),1.0f);
}

fragment CrowAOVOutput showcaseCrowBackgroundAOVFragment(
    RasterVertex in [[stage_in]],
    constant float4& options [[buffer(0)]]) {
    float3 sky=showcaseCrowBackgroundRadiance(in.uv,options);
    CrowAOVOutput out;
    out.beauty=half4(half3(sky),half(1));
    out.albedoAndMaterial=half4(half3(sky),half(0));
    out.normal=half4(0);
    out.motion=half2(0);
    out.metricDepth=0.0f;
    return out;
}

vertex RasterVertex showcasePostVertex(uint vid [[vertex_id]]) {
    float2 positions[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};
    RasterVertex out;
    out.position=float4(positions[vid],0,1);
    out.world=float3(0);out.normal=float3(0,0,1);out.color=float4(1);
    out.uv=0.5f*(positions[vid]+1.0f);
    return out;
}

fragment half4 showcaseCrowNormalResolveFragment(
    RasterVertex in [[stage_in]],
    texture2d<half> resolvedNormal [[texture(0)]]) {
    uint2 pixel=uint2(in.position.xy);
    half4 rawNormal=resolvedNormal.read(pixel);
    float normalLength=length(float3(rawNormal.xyz));
    half3 normal=normalLength>1.0e-6f
        ? half3(float3(rawNormal.xyz)/normalLength)
        : half3(0);
    return half4(normal,rawNormal.w);
}

fragment half showcaseCrowReactiveMaskFragment(
    RasterVertex in [[stage_in]],
    texture2d<half> motionTexture [[texture(0)]],
    texture2d<half> normalCoverageTexture [[texture(1)]]) {
    uint2 pixel=uint2(in.position.xy);
    uint2 maximum=uint2(
        motionTexture.get_width()-1,
        motionTexture.get_height()-1
    );
    uint2 right=min(pixel+uint2(1,0),maximum);
    uint2 down=min(pixel+uint2(0,1),maximum);
    float2 motion=float2(motionTexture.read(pixel).xy);
    float2 rightMotion=float2(motionTexture.read(right).xy);
    float2 downMotion=float2(motionTexture.read(down).xy);
    float coverage=float(normalCoverageTexture.read(pixel).w);
    float rightCoverage=float(normalCoverageTexture.read(right).w);
    float downCoverage=float(normalCoverageTexture.read(down).w);
    float3 normal=float3(normalCoverageTexture.read(pixel).xyz);
    float3 rightNormal=float3(normalCoverageTexture.read(right).xyz);
    float3 downNormal=float3(normalCoverageTexture.read(down).xyz);
    float motionDiscontinuity=max(
        length(motion-rightMotion),length(motion-downMotion)
    );
    float coverageDiscontinuity=max(
        abs(coverage-rightCoverage),abs(coverage-downCoverage)
    );
    float normalDiscontinuity=max(
        min(coverage,rightCoverage)*(1.0f-abs(dot(normal,rightNormal))),
        min(coverage,downCoverage)*(1.0f-abs(dot(normal,downNormal)))
    );
    float edge=max(
        smoothstep(0.75f,8.0f,motionDiscontinuity),
        smoothstep(0.04f,0.55f,coverageDiscontinuity)
    );
    edge=max(edge,0.65f*smoothstep(0.015f,0.22f,normalDiscontinuity));
    float fastMotion=0.72f*smoothstep(8.0f,32.0f,length(motion));
    return half(max(edge,fastMotion));
}

fragment float4 showcaseCrowToneMapFragment(
    RasterVertex in [[stage_in]],
    texture2d<half> hdrColor [[texture(0)]]) {
    uint2 pixel=uint2(in.position.xy);
    float3 radiance=float3(hdrColor.read(pixel).rgb);
    return float4(1.0f-exp(-max(radiance,0.0f)),1.0f);
}

inline float showcaseBloomWeight(float3 color) {
    float luminance=dot(color,float3(0.2126f,0.7152f,0.0722f));
    return smoothstep(0.18f,0.82f,luminance);
}

fragment float4 showcaseBloomFragment(
    RasterVertex in [[stage_in]],
    texture2d<float> scene [[texture(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float2 texel=1.0f/float2(scene.get_width(),scene.get_height());
    const float weights[3]={0.40262f,0.24420f,0.05449f};
    float3 bloom=float3(0);
    for(int y=-2;y<=2;++y){
        for(int x=-2;x<=2;++x){
            float3 sampleColor=scene.sample(
                s,in.uv+float2(x,y)*texel*4.2f).rgb;
            float weight=weights[abs(x)]*weights[abs(y)];
            bloom+=weight*sampleColor*showcaseBloomWeight(sampleColor);
        }
    }
    return float4(bloom,1);
}

fragment float4 showcaseCompositeFragment(
    RasterVertex in [[stage_in]],
    constant float4& finishing [[buffer(0)]],
    texture2d<float> scene [[texture(0)]],
    texture2d<float> bloom [[texture(1)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float3 base=scene.sample(s,in.uv).rgb;
    float3 glow=bloom.sample(s,in.uv).rgb;
    float3 color=(base+finishing.x*glow)*finishing.y;
    float3 excess=max(color-0.94f,0.0f);
    color=min(color-excess+0.06f*(1.0f-exp(-4.0f*excess)),1.0f);
    float2 centered=in.uv-0.5f;
    float vignette=1.0f-0.10f*smoothstep(0.28f,0.72f,length(centered));
    color*=vignette;
    color=mix(color,color*float3(0.96f,1.01f,1.05f),0.18f);
    return float4(color,1);
}

vertex RasterVertex sliceVertex(
    constant VisualizationUniforms& u [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    float2 corners[6]={float2(-1,-1),float2(1,-1),float2(1,1),float2(-1,-1),float2(1,1),float2(-1,1)};
    float2 c=corners[vid];float3 world=u.sliceCenterAndOpacity.xyz+c.x*u.sliceUAndHalfWidth.w*u.sliceUAndHalfWidth.xyz+c.y*u.sliceVAndHalfHeight.w*u.sliceVAndHalfHeight.xyz;
    RasterVertex out;out.position=camera.viewProjection*float4(world,1);out.world=world;out.normal=u.sliceNormalAndRange.xyz;out.color=float4(1);out.uv=0.5f*(c+1.0f);return out;
}

fragment float4 sliceFragment(RasterVertex in [[stage_in]],texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);return texture.sample(s,in.uv);
}

vertex RasterVertex ribbonVertex(
    device const float4* history [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    constant uint& tracerIndex [[buffer(2)]],
    constant uint& historyLength [[buffer(3)]],
    constant VisualizationUniforms& u [[buffer(4)]],
    uint vid [[vertex_id]]) {
    uint segment=min(vid/2u,historyLength-1u);float side=(vid&1u)?1.0f:-1.0f;
    uint base=tracerIndex*historyLength;float3 p=history[base+segment].xyz;
    float3 previous=history[base+(segment>0u?segment-1u:segment)].xyz;
    float3 next=history[base+min(segment+1u,historyLength-1u)].xyz;
    float3 tangent=normalize(next-previous+float3(1.0e-12f,0,0));
    float3 view=normalize(camera.eyeAndWidth.xyz-p);float3 lateral=normalize(cross(view,tangent));
    float age=1.0f-float(segment)/max(float(historyLength-1u),1.0f);float3 world=p+lateral*camera.eyeAndWidth.w*side*age;
    RasterVertex out;out.position=camera.viewProjection*float4(world,1);out.world=world;out.normal=view;
    out.color=float4(sequentialMap(history[base+segment].w/u.displayOptions.z),0.7f*age);out.uv=float2(0);return out;
}

fragment float4 unlitFragment(RasterVertex in [[stage_in]]) { return in.color; }
