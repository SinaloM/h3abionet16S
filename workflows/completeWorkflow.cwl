#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow

requirements:
 - class: ScatterFeatureRequirement
 - class: InlineJavascriptRequirement
 - class: StepInputExpressionRequirement
 - class: SchemaDefRequirement
   types:
    - name: FilePairs
      type: record
      fields:
        - name: forward
          type: File
        - name: reverse
          type: File

inputs:
  fastqSeqs: FilePairs[]
  fastqMaxdiffs: int

outputs:
  #reports:
  #  type: Directory[]
  #  outputSource: runFastqc/report
  mergedFastQs:
     type: File[]
     outputSource: merge/mergedFastQ

steps:
  arrayOfFilePairsToFileArray:
    run:
      class: ExpressionTool
      inputs:
        arrayOfFilePairs: FilePairs[]
      outputs:
        pairByPairs: File[]
      expression: >
        ${
        var val;
        var ret = [];
        for (val of inputs.arrayOfFilePairs) {
          ret.push(val.forward);
          ret.push(val.reverse);
        }
        return { 'pairByPairs': ret } ; }
    in:
      arrayOfFilePairs: fastqSeqs
    out: [ pairByPairs ]

  runFastqc:
    run: fastqc.cwl
    in:
      fastqFile: arrayOfFilePairsToFileArray/pairByPairs
    scatter: fastqFile
    out: [ report ]

  uparseRename:
    run: uparseRenameFastQ.cwl
    in:
      sampleName:
        source: fastqSeqs
        valueFrom: $(self.sample_id)
      fastqFileF:
        source: fastqSeqs
        valueFrom: $(self.forward)
      fastqFileR:
        source: fastqSeqs
        valueFrom: $(self.reverse)
    scatter: [ sampleName, fastqFileF, fastqFileR ]
    scatterMethod: dotproduct
    out: [ forwardRename, reverseRename ]

  merge:
    run: uparseFastqMerge.cwl
    in:
      fastqFileF: uparseRename/forwardRename
      fastqFileR: uparseRename/reverseRename
      fastqMaxdiffs: fastqMaxdiffs
    scatter: [ fastqFileF, fastqFileR ]
    scatterMethod: dotproduct
    out: [ mergedFastQ ]
