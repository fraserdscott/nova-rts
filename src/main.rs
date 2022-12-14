use std::{
    collections::HashMap,
    env::current_dir,
    time::Instant,
};

use nova_scotia::{
    circom::reader::load_r1cs, create_public_params, create_recursive_circuit, F1, G1, G2,
};
use nova_snark::{traits::Group, CompressedSNARK};
use serde_json::json;

const N_EVENTS: usize = 32;

fn main() {
    let iteration_count = 4;
    let root = current_dir().unwrap();

    let circuit_file = root.join("src/circuits/event.r1cs");
    let r1cs = load_r1cs(&circuit_file);
    let witness_generator_file_js = root.join("src/circuits/event_js/generate_witness.js");
    let witness_generator_file_wasm = root.join("src/circuits/event_js/event.wasm");

    let zeros: [u32; N_EVENTS] = [0; N_EVENTS];
    let zero_coords: [[u32; 2]; N_EVENTS] = [[0, 0]; N_EVENTS];

    let mut private_inputs = Vec::new();
    for i in 0..iteration_count {
        let mut private_input = HashMap::new();
        private_input.insert("frames".to_string(), json!(zeros));
        private_input.insert("players".to_string(), json!(zeros));
        private_input.insert("units".to_string(), json!(zeros));
        private_input.insert("vectors".to_string(), json!(zero_coords));
        private_inputs.push(private_input);

    }

    let start_public_input = vec![F1::from(0)];

    let pp = create_public_params(r1cs.clone());

    println!(
        "Number of constraints per step (primary circuit): {}",
        pp.num_constraints().0
    );
    println!(
        "Number of constraints per step (secondary circuit): {}",
        pp.num_constraints().1
    );

    println!(
        "Number of variables per step (primary circuit): {}",
        pp.num_variables().0
    );
    println!(
        "Number of variables per step (secondary circuit): {}",
        pp.num_variables().1
    );

    println!("Creating a RecursiveSNARK...");
    let start = Instant::now();
    let recursive_snark = create_recursive_circuit(
        witness_generator_file_js,
        witness_generator_file_wasm,
        r1cs,
        private_inputs,
        start_public_input.clone(),
        &pp,
    )
    .unwrap();
    println!("RecursiveSNARK creation took {:?}", start.elapsed());

    // TODO: empty?
    let z0_secondary = vec![<G2 as Group>::Scalar::zero()];

    // verify the recursive SNARK
    println!("Verifying a RecursiveSNARK...");
    let start = Instant::now();
    let res = recursive_snark.verify(
        &pp,
        iteration_count,
        start_public_input.clone(),
        z0_secondary.clone(),
    );
    println!(
        "RecursiveSNARK::verify: {:?}, took {:?}",
        res,
        start.elapsed()
    );
    assert!(res.is_ok());

    // produce a compressed SNARK
    println!("Generating a CompressedSNARK using Spartan with IPA-PC...");
    let start = Instant::now();
    type S1 = nova_snark::spartan_with_ipa_pc::RelaxedR1CSSNARK<G1>;
    type S2 = nova_snark::spartan_with_ipa_pc::RelaxedR1CSSNARK<G2>;
    let res = CompressedSNARK::<_, _, _, _, S1, S2>::prove(&pp, &recursive_snark);
    println!(
        "CompressedSNARK::prove: {:?}, took {:?}",
        res.is_ok(),
        start.elapsed()
    );
    assert!(res.is_ok());
    let compressed_snark = res.unwrap();

    // verify the compressed SNARK
    println!("Verifying a CompressedSNARK...");
    let start = Instant::now();
    let res = compressed_snark.verify(
        &pp,
        iteration_count,
        start_public_input.clone(),
        z0_secondary,
    );
    println!(
        "CompressedSNARK::verify: {:?}, took {:?}",
        res.is_ok(),
        start.elapsed()
    );
    assert!(res.is_ok());
}