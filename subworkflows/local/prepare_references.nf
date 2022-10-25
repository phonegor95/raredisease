//
// Prepare reference files
//

include { BWA_INDEX                                          } from '../../modules/nf-core/bwa/index/main'
include { BWAMEM2_INDEX                                      } from '../../modules/nf-core/bwamem2/index/main'
include { BWAMEM2_INDEX as BWAMEM2_INDEX_SHIFT_MT            } from '../../modules/nf-core/bwamem2/index/main'
include { CAT_CAT as CAT_CAT_BAIT                            } from '../../modules/nf-core/cat/cat/main'
include { CHECK_VCF                                          } from './prepare_vcf'
include { GATK4_BEDTOINTERVALLIST as GATK_BILT               } from '../../modules/nf-core/gatk4/bedtointervallist/main'
include { GATK4_CREATESEQUENCEDICTIONARY as GATK_SD          } from '../../modules/nf-core/gatk4/createsequencedictionary/main'
include { GATK4_CREATESEQUENCEDICTIONARY as GATK_SD_SHIFT_MT } from '../../modules/nf-core/gatk4/createsequencedictionary/main'
include { GATK4_INTERVALLISTTOOLS as GATK_ILT                } from '../../modules/nf-core/gatk4/intervallisttools/main'
include { GET_CHROM_SIZES                                    } from '../../modules/local/get_chrom_sizes'
include { SAMTOOLS_FAIDX                                     } from '../../modules/nf-core/samtools/faidx/main'
include { SAMTOOLS_FAIDX as SAMTOOLS_FAIDX_SHIFT_MT          } from '../../modules/nf-core/samtools/faidx/main'
include { SENTIEON_BWAINDEX                                  } from '../../modules/local/sentieon/bwamemindex'
include { TABIX_BGZIPTABIX as TABIX_PBT                      } from '../../modules/nf-core/tabix/bgziptabix/main'
include { TABIX_TABIX as TABIX_DBSNP                         } from '../../modules/nf-core/tabix/tabix/main'
include { TABIX_TABIX as TABIX_GNOMAD_AF                     } from '../../modules/nf-core/tabix/tabix/main'
include { TABIX_TABIX as TABIX_PT                            } from '../../modules/nf-core/tabix/tabix/main'
include { UNTAR as UNTAR_VCFANNO                             } from '../../modules/nf-core/untar/main'


workflow PREPARE_REFERENCES {
    take:
        fasta_no_meta               // [mandatory] genome.fasta
        fasta_meta
        fai                 // [optional ] genome.fai
        mt_fasta_shift_no_meta
        mt_fasta_shift_meta
        gnomad_af_tab
        gnomad_vcf_in
        known_dbsnp
        target_bed
        vcfanno_resources   // [mandatory] vcfanno resource file

    main:
        ch_versions   = Channel.empty()
        ch_tbi        = Channel.empty()
        ch_bgzip_tbi  = Channel.empty()

        BWA_INDEX(fasta_meta)
        BWAMEM2_INDEX(fasta_meta)
        BWAMEM2_INDEX_SHIFT_MT(mt_fasta_shift_meta)
        SENTIEON_BWAINDEX(fasta_meta)
        SAMTOOLS_FAIDX(fasta_meta)
        SAMTOOLS_FAIDX_SHIFT_MT(mt_fasta_shift_meta)
        GATK_SD(fasta_no_meta)
        GATK_SD_SHIFT_MT(mt_fasta_shift_no_meta)
        GET_CHROM_SIZES( SAMTOOLS_FAIDX.out.fai )
        TABIX_DBSNP(known_dbsnp)
        TABIX_GNOMAD_AF(gnomad_af_tab)
        CHECK_VCF(gnomad_vcf_in, fasta_no_meta)
        TABIX_PT(target_bed).tbi.set { ch_tbi }
        TABIX_PBT(target_bed).gz_tbi.set { ch_bgzip_tbi }
        GATK_BILT(target_bed, GATK_SD.out.dict).interval_list
        GATK_ILT(GATK_BILT.out.interval_list)
        GATK_ILT.out.interval_list
            .collect{ it[1] }
            .map { it ->
                meta = it[0].toString().split("_split")[0].split("/")[-1] + "_bait.intervals_list"
                return [[id:meta], it]
            }
            .set { ch_bait_intervals_cat_in }
        CAT_CAT_BAIT ( ch_bait_intervals_cat_in )
        UNTAR_VCFANNO ( vcfanno_resources )

        // Gather versions
        ch_versions = ch_versions.mix(BWA_INDEX.out.versions)
        ch_versions = ch_versions.mix(BWAMEM2_INDEX.out.versions)
        ch_versions = ch_versions.mix(BWAMEM2_INDEX_SHIFT_MT.out.versions)
        ch_versions = ch_versions.mix(SENTIEON_BWAINDEX.out.versions)
        ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)
        ch_versions = ch_versions.mix(SAMTOOLS_FAIDX_SHIFT_MT.out.versions)
        ch_versions = ch_versions.mix(GATK_SD.out.versions)
        ch_versions = ch_versions.mix(GATK_SD_SHIFT_MT.out.versions)
        ch_versions = ch_versions.mix(GET_CHROM_SIZES.out.versions)
        ch_versions = ch_versions.mix(TABIX_DBSNP.out.versions)
        ch_versions = ch_versions.mix(TABIX_GNOMAD_AF.out.versions)
        ch_versions = ch_versions.mix(CHECK_VCF.out.versions)
        ch_versions = ch_versions.mix(TABIX_PT.out.versions)
        ch_versions = ch_versions.mix(TABIX_PBT.out.versions)
        ch_versions = ch_versions.mix(GATK_BILT.out.versions)
        ch_versions = ch_versions.mix(GATK_ILT.out.versions)
        ch_versions = ch_versions.mix(UNTAR_VCFANNO.out.versions)

    emit:
        bait_intervals            = CAT_CAT_BAIT.out.file_out.map { id, it -> [it] }
        bwa_index                 = BWA_INDEX.out.index ?: SENTIEON_BWAINDEX.out.index
        bwamem2_index             = BWAMEM2_INDEX.out.index
        bwamem2_index_mt_shift    = BWAMEM2_INDEX_SHIFT_MT.out.index
        chrom_sizes               = GET_CHROM_SIZES.out.sizes
        fasta_fai                 = SAMTOOLS_FAIDX.out.fai.map{ meta, fai -> [fai] }
        fasta_fai_mt_shift        = SAMTOOLS_FAIDX_SHIFT_MT.out.fai.map{ meta, fai -> [fai] }
        gnomad_af_idx             = TABIX_GNOMAD_AF.out.tbi
        gnomad_tbi                = CHECK_VCF.out.index
        gnomad_vcf                = CHECK_VCF.out.vcf
        known_dbsnp_tbi           = TABIX_DBSNP.out.tbi
        sequence_dict             = GATK_SD.out.dict
        sequence_dict_mt_shift    = GATK_SD_SHIFT_MT.out.dict
        target_bed                = Channel.empty().mix(ch_tbi, ch_bgzip_tbi)
        target_intervals          = GATK_BILT.out.interval_list.collect{it[1]}
        vcfanno_resources         = UNTAR_VCFANNO.out.untar.map { id, resources -> [resources] }
        versions                  = ch_versions

}

