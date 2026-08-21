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
        result.root=center+float3(
            0.040f-0.132f*fraction,
            side*0.042f,
            0.032f-0.024f*fraction
        );
        float primaryTipLateralOffset=0.003f+0.001f*fraction
            -0.003f*fraction*fraction*fraction;
        float lateralDirection=side*(primaryTipLateralOffset-0.042f)/featherLength;
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
            float3(0.030f,side,0.20f+0.08f*fraction),
            float3(0,side,0)
        );
    }else if(featherClass==2u){
        float featherLength=0.112f+0.030f*fraction;
        result.root=center+float3(
            0.082f-0.142f*fraction,
            side*0.047f,
            0.044f-0.024f*fraction
        );
        float secondaryTipLateralOffset=0.027f+0.002f*fraction;
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
        float targetZ=-0.025f-0.006f*radialFraction;
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
    state.currentPositionAndLength=float4(
        current.root,binding.morphology.x*lengthScale
    );
    state.previousPositionAndWidth=float4(previous.root,binding.morphology.y);
    state.currentDirectionAndRachis=float4(current.direction,binding.morphology.z);
    state.previousDirectionAndCamber=float4(previous.direction,binding.morphology.w);
    state.currentNormalAndPadding=float4(current.normal,0);
    state.previousNormalAndPadding=float4(previous.normal,0);
    state.previousMorphology=binding.morphology;
    state.previousMorphology.x*=lengthScale;
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
        (-0.025f-0.006f*radialFraction-closedRoot.z)/closedLength;
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
    float terminalRatio=0.13f+0.03f*(1.0f-rectrix.x);
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
    float halfWidth=0.00010f*(1.0f-0.28f*axial);
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
    bool temporallyVariableMorphology=isLiveCovert;
    bool detailEnabled=parameter.z<0.5f
        ||(uniforms.renderOffsetAndDetailScale.w>=parameter.z
            &&(featherClass==1u||featherClass==2u||isLiveCovert));
    float3 current=detailEnabled
        ?crowFeatherDetailPosition(
            root.currentPositionAndLength.xyz,currentDirection,currentNormal,
            lengthMeters,maximumWidthMeters,camberMeters,
            root.currentDirectionAndRachis.w,parameter.x,parameter.y,
            parameter.z,parameter.w,packedIdentity
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
            parameter.z,parameter.w,packedIdentity
        )
        :root.previousPositionAndWidth.xyz;
    current+=uniforms.renderOffsetAndDetailScale.xyz;
    previous+=uniforms.renderOffsetAndDetailScale.xyz;
    float3 deformedNormal=detailEnabled
        ?crowFeatherDetailNormal(
            currentDirection,currentNormal,lengthMeters,maximumWidthMeters,
            camberMeters,parameter.x,parameter.y,parameter.z,parameter.w,
            packedIdentity
        ):currentNormal;
    float material=featherClass==1u?0.25f:
        (featherClass==2u?0.22f:(isUnderwingCovert?0.17f:0.23f));
    float shade=isUnderwingCovert
        ?0.0066f+0.00022f*float(root.identity.x%9u)
        :0.0075f+0.00045f*float(root.identity.x%11u);
    float greenScale=isUnderwingCovert?1.45f:1.28f;
    float blueScale=isUnderwingCovert?2.55f:1.72f;
    float detailShadeScale=parameter.z>0.5f
        ?(parameter.z<1.5f?1.18f:1.08f):1.0f;
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
        parameter.y,float(featherClass),parameter.z
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
    }
    return clipPosition;
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

inline float3 showcaseCrowLinearRadiance(
    float3 world,
    float3 normalInput,
    float4 albedoAndMaterial,
    float3 eyePosition,
    float3 featherCoordinates,
    uint packedIdentity) {
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

    // Eumelanin makes the body nearly black while a weak, view-dependent
    // cortex response adds the restrained blue/violet sheen of adult crow
    // feather regions. Keep the phase in the local vane frame: a world-space
    // wave would visibly slide over feathers as the standing body moves.
    float grazing=pow(1.0f-ndv,1.55f);
    float flightFeather=smoothstep(0.19f,0.25f,material);
    float featherMaterial=1.0f-smoothstep(0.46f,0.50f,material);
    float vaneCoordinates=step(1.0e-5f,
        abs(featherCoordinates.x)+abs(featherCoordinates.y));
    float persistentVane=featherMaterial*vaneCoordinates;
    float axial=saturate(featherCoordinates.x);
    float signedWidth=clamp(featherCoordinates.y,-1.0f,1.0f);
    float cortexPhase=
        29.0f*ndv
        +2.10f*featherCoordinates.z
        +3.25f*axial
        +0.85f*abs(signedWidth);
    float localCortexResponse=0.5f+0.5f*crowBandLimitedSine(cortexPhase);
    float interference=mix(0.5f,localCortexResponse,persistentVane);
    float3 blue=float3(0.025f,0.055f,0.090f);
    float3 violet=float3(0.065f,0.035f,0.075f);
    float3 sheen=mix(blue,violet,interference);
    uint featherClass=packedIdentity&255u;
    float primaryVane=featherClass==1u?persistentVane:0.0f;
    float secondaryVane=featherClass==2u?persistentVane:0.0f;
    float rectrixVane=featherClass==3u?persistentVane:0.0f;
    float underwingCovertVane=
        (featherClass==12u||featherClass==13u)?persistentVane:0.0f;
    float greaterCovertVane=
        (featherClass==4u||featherClass==12u||featherClass==13u
            ||featherClass==14u||featherClass==15u)
            ?persistentVane:0.0f;
    float dorsalBodyVane=featherClass==5u?persistentVane:0.0f;
    float flankBodyVane=featherClass==6u?persistentVane:0.0f;
    float ventralBodyVane=featherClass==7u?persistentVane:0.0f;
    float headNeckVane=featherClass==8u?persistentVane:0.0f;
    float foreheadVane=featherClass==9u?persistentVane:0.0f;
    float gularVane=featherClass==10u?persistentVane:0.0f;
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
    classSheenScale=mix(classSheenScale,0.67f,flankBodyVane);
    classSheenScale=mix(classSheenScale,0.62f,ventralBodyVane);
    classSheenScale=mix(classSheenScale,0.60f,headNeckVane);
    classSheenScale=mix(classSheenScale,0.38f,foreheadVane);
    classSheenScale=mix(classSheenScale,0.52f,gularVane);
    float3 featherAxis=crowFeatherAxis(
        world,normal,featherCoordinates.xy
    );
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
        *(0.055f*bodyOpticalIdentity+0.018f*bodyOpticalDrift);
    float3 featherBarbAxis=safeNormalizeCrow(
        cross(normal,featherAxis),float3(0.0f,1.0f,0.0f)
    );
    float3 bodyOpticalAxis=safeNormalizeCrow(
        featherAxis*cos(bodyOpticalTurn)
            +featherBarbAxis*sin(bodyOpticalTurn),
        featherAxis
    );
    float bankIdentity=0.5f+0.5f*crowBandLimitedSine(
        2.39f*featherCoordinates.z+0.67f*float(featherClass)
    );
    float bodyBankSpread=bodyContourVane*(0.105f+0.030f*bankIdentity);
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
    longitudinalRoughness=mix(longitudinalRoughness,0.340f,flankBodyVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.350f,ventralBodyVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.360f,headNeckVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.390f,foreheadVane);
    longitudinalRoughness=mix(longitudinalRoughness,0.370f,gularVane);
    transverseRoughness=mix(transverseRoughness,0.142f,dorsalBodyVane);
    transverseRoughness=mix(transverseRoughness,0.148f,flankBodyVane);
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
    float genericAnisotropicSpecular=crowFeatherAnisotropicLobe(
        normal,featherAxis,halfVector,
        longitudinalRoughness,transverseRoughness
    );
    float bodyBankAnisotropicSpecular=0.5f*(
        crowFeatherAnisotropicLobe(
            normal,firstBodyBank,halfVector,
            longitudinalRoughness,transverseRoughness
        )
        +crowFeatherAnisotropicLobe(
            normal,secondBodyBank,halfVector,
            longitudinalRoughness,transverseRoughness
        )
    );
    float anisotropicSpecular=featherMaterial*vaneAnisotropy*mix(
        genericAnisotropicSpecular,
        bodyBankAnisotropicSpecular,
        bodyContourVane
    );
    float genericRachisAxial=smoothstep(0.035f,0.16f,axial)
        *(1.0f-smoothstep(0.80f,0.985f,axial));
    float bodyRachisAxial=smoothstep(0.48f,0.60f,axial)
        *(1.0f-smoothstep(0.82f,0.94f,axial));
    float bodyRachisIdentity=0.5f+0.5f*crowBandLimitedSine(
        1.73f*featherCoordinates.z+0.31f*float(featherClass)
    );
    float bodyRachisScale=0.16f+0.18f*bodyRachisIdentity;
    float rachis=persistentVane*(1.0f-greaterCovertVane)
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
    )*persistentVane;
    float barbPhase=520.0f*world.x+390.0f*world.y-270.0f*world.z;
    float barb=0.5f+0.5f*crowBandLimitedSine(barbPhase);
    float barbSignal=mix(barb,localBarbs,persistentVane);
    float barbMicro=persistentVane
        *mix(0.006f+0.010f*barbSignal,0.010f+0.018f*barbSignal,flightFeather)
        *grazing*mix(0.25f,1.0f,flightFeather);
    float vaneEdge=persistentVane*smoothstep(0.78f,0.98f,abs(signedWidth))
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
    float barbuleTilt=mix(0.006f,0.014f,flightFeather)
        *interlockingBarbules.x;
    float3 specularNormal=safeNormalizeCrow(
        normal+(bodyBarbTilt+barbuleTilt)*bodyBarbAxis
            +0.45f*barbuleTilt*featherAxis,
        normal
    );
    // Overlapping body contours form a broader collective cortex response at
    // whole-bird distance. Preserve the tight exponent on exposed flight
    // feathers while preventing every body vane from becoming a silver rib.
    float sharpExponent=mix(92.0f,44.0f,bodyContourVane);
    float featherSpecular=pow(
        saturate(dot(specularNormal,halfVector)),sharpExponent
    );
    float softSpecular=pow(saturate(dot(normal,halfVector)),24.0f);
    float diffuse=0.28f+0.62f*ndk+0.16f*ndf+0.10f*nds;
    float flightDarkening=mix(1.0f,0.58f,flightFeather);
    float3 color=albedoAndMaterial.rgb*diffuse*flightDarkening;
    color*=mix(1.0f,0.82f,foreheadVane);
    color+=sheen*(0.022f+0.125f*grazing)*(0.36f+0.64f*ndk)
        *flightDarkening*(0.72f+0.28f*anisotropicSpecular)
        *classSheenScale;
    color+=barbMicro*classSheenScale
        *mix(float3(0.035f,0.070f,0.11f),sheen,0.45f);
    color+=interlockingBarbules.y*grazing*classSheenScale
        *mix(float3(0.0025f,0.0055f,0.0090f),sheen,0.28f);
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
    classSharpScale=mix(classSharpScale,0.28f,ventralBodyVane);
    classSharpScale=mix(classSharpScale,0.28f,headNeckVane);
    classSharpScale=mix(classSharpScale,0.20f,foreheadVane);
    classSharpScale=mix(classSharpScale,0.24f,gularVane);
    color+=sharpTint*featherSpecular*mix(0.30f,1.0f,flightFeather)
        *classSharpScale;
    color+=softTint*softSpecular;
    float classAnisotropicScale=mix(1.0f,0.40f,bodyContourVane);
    color+=classAnisotropicScale*anisotropicSpecular
        *mix(float3(0.020f,0.030f,0.046f),float3(0.012f,0.020f,0.034f),flightFeather);
    color*=1.0f-0.055f*persistentVane*(1.0f-localBarbs);
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
    // added here; blue/violet structure stays view-dependent in `sheen`.
    color+=nds*float3(0.004f,0.006f,0.010f);
    color+=rim*mix(1.0f,classSheenScale,persistentVane)
        *float3(0.022f,0.040f,0.065f);
    return 1.68f*color;
}

fragment float4 showcaseCrowFragment(
    RasterVertex in [[stage_in]],
    constant CameraUniforms& camera [[buffer(0)]]) {
    float3 radiance=showcaseCrowLinearRadiance(
        in.world,in.normal,in.color,camera.eyeAndWidth.xyz,float3(in.uv,0),0u
    );
    return float4(1.0f-exp(-radiance),1.0f);
}

fragment CrowAOVOutput showcaseCrowAOVFragment(
    CrowRasterVertex in [[stage_in]],
    constant CrowTemporalCameraUniforms& camera [[buffer(0)]]) {
    float3 normal=in.normal;
    float3 radiance=showcaseCrowLinearRadiance(
        in.world,normal,in.albedoAndMaterial,camera.eyeAndWidth.xyz,
        in.featherCoordinates,in.identity.w
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
