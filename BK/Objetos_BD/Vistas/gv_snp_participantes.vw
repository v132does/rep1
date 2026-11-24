CREATE OR REPLACE FORCE VIEW IT.GV_SNP_PARTICIPANTES AS
SELECT b.cod_swift cod_swift, 'BA' tipo, b.cod_banco, NULL cod_ente,
       b.descripcion participante, pe.cod_persona,
        CASE WHEN fue_per_dat_adicional( pe.cod_persona, 'SNP_PER_SWI_PROPIO' ) = 'N' THEN 'N' ELSE 'S' END ind_swi_propio,
       CASE WHEN fue_per_dat_adicional( pe.cod_persona, 'SNP_HAB_BCO_PTE_HB' ) = 'N' THEN 'N' ELSE 'S' END ind_hab_pte_hb,
       CASE WHEN fue_per_dat_adicional( pe.cod_persona, 'SNP_VAL_BCO_FMT_MENSAJE' ) = 'N' THEN 'N' ELSE 'S' END ind_val_fmt_msj_recibido,
       CASE WHEN fue_per_dat_adicional( pe.cod_persona, 'SPI_PTE_CER_BCP' ) = 'S' THEN 'S' ELSE 'N' END ind_hab_pte_spi
  FROM ge_bancos b, ba_personas pe
 WHERE b.ubicacion   = 'L'
   AND b.estado      = 'A'
   AND b.cod_persona = pe.cod_persona
   AND b.cod_swift IS NOT NULL
UNION ALL
SELECT pe.val_parametro cod_swift,  e.tipo, null, e.cod_ente,
       e.descripcion participante, e.cod_persona,
       CASE WHEN pen.val_parametro = 'S' THEN 'S' ELSE 'N' END ind_swi_propio,
       CASE WHEN pae.val_parametro = 'N' THEN 'N' ELSE 'S' END ind_hab_pte_hb,
       CASE WHEN pet.val_parametro = 'N' THEN 'N' ELSE 'S' END ind_val_fmt_msj_recibido,
       CASE WHEN fue_per_dat_adicional( p.cod_persona, 'SPI_PTE_CER_BCP' ) = 'S' THEN 'S' ELSE 'N' END ind_hab_pte_spi
  FROM ge_entes e, ge_par_entes pe, ba_personas p,
       ge_par_entes pen, ge_par_entes pae, ge_par_entes pet
 WHERE e.cod_persona    = p.cod_persona
   AND e.tipo           = 'PS'
   AND pe.cod_ente      = e.cod_ente
   AND pe.parametro     = 'COD_SWIFT'
   AND pe.val_parametro IS NOT NULL
   AND pen.cod_ente(+)  = e.cod_ente
   AND pen.parametro(+) = 'SNP_SWI_PROPIO'
   AND pae.cod_ente(+)  = e.cod_ente
   AND pae.parametro(+) = 'SNP_HAB_ENT_PTE_HB'
   AND pet.cod_ente(+)  = e.cod_ente
   AND pet.parametro(+) = 'SNP_VAL_ENT_FMT_MENSAJE';
/
