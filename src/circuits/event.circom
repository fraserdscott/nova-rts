pragma circom 2.0.3;

include "../node_modules/circomlib/circuits/poseidon.circom";

template EventHash(D) {
    signal input step_in;           // The sequential hash of each previous event 
    signal output step_out;         // The sequential hash of each previous event, plus this event
    
    signal input frame;             // The frame that this event took place in
    signal input account;           // The account that logged this event
    signal input unit;              // The selected unit for this event
    // signal input vector[D];         // The new movement vector for the selected unit for this event

    component hash = Poseidon(4);
    hash.inputs[0] <== step_in;
    hash.inputs[1] <== frame;
    hash.inputs[2] <== account;
    hash.inputs[3] <== unit;
    // for (var i=0; i < D; i++) { 
    //     hash.inputs[4+i] <== vector[i];
    // }

    step_out <== hash.out;
}

component main { public [step_in] } = EventHash(2);