CREATE OR REPLACE PROCEDURE IT.prs_act_mto_garantias IS
   v_mto_tas_ase_equ_local    sb_crc_garantias_det.mto_tas_ase_equ_local%TYPE;
   v_mto_tas_no_ase_equ_local sb_crc_garantias_det.mto_tas_no_ase_equ_local%TYPE;
   v_mto_seg_equ_local        sb_crc_garantias_det.mto_seg_equ_local%TYPE;
   v_mto_gar_equ_local        sb_crc_garantias_det.mto_gar_equ_local%TYPE;
   v_mto_tas_asegurable       sb_crc_garantias_det.mto_tas_asegurable%TYPE;
   v_mto_tas_no_asegurable    sb_crc_garantias_det.mto_tas_no_asegurable%TYPE; 
   v_mto_asegurado            sb_crc_garantias_det.mto_asegurado%TYPE; 
   v_mto_garantia             sb_crc_garantias_det.mto_garantia%TYPE;
   v_cod_mon_tasacion         pr_garantias.cod_mon_tasacion%TYPE;
   v_nro_garantia             pr_garantias.nro_garantia%TYPE;
   
CURSOR c_garantias IS
      SELECT *
        FROM sb_crc_garantias_det
       WHERE mto_seg_equ_local IS NULL
         AND mto_gar_equ_local IS NULL
         AND mto_tas_ase_equ_local IS NULL
         AND mto_tas_no_ase_equ_local IS NULL;

BEGIN
   FOR reg IN c_garantias LOOP
      v_mto_seg_equ_local        := reg.mto_asegurado;
      v_mto_gar_equ_local        := reg.mto_garantia;
      v_mto_tas_ase_equ_local    := reg.mto_tas_asegurable;
      v_mto_tas_no_ase_equ_local := reg.mto_tas_no_asegurable;
      v_nro_garantia             := reg.nro_garantia;
      BEGIN
         SELECT valor
           INTO v_mto_garantia
           FROM sv_garantias
          WHERE estado = 'C'
            AND nro_garantia = reg.nro_garantia;
      EXCEPTION
         WHEN OTHERS THEN
            v_mto_garantia := 0;
      END;
      BEGIN
         SELECT SUM(det.mto_tas_asegurable),
                SUM(det.mto_tas_no_asegurable),
                SUM(det.mto_asegurado),
                det.cod_mon_tasacion
           INTO v_mto_tas_asegurable, v_mto_tas_no_asegurable, v_mto_asegurado, v_cod_mon_tasacion
           FROM sv_garantias_det det
          WHERE det.nro_garantia = reg.nro_garantia
          GROUP BY det.nro_garantia, det.cod_mon_tasacion;
      EXCEPTION
         WHEN OTHERS THEN
            v_mto_tas_asegurable    := 0;
            v_mto_tas_no_asegurable := 0;
            v_mto_asegurado         := 0;
      END;
   
      UPDATE sb_crc_garantias_det
         SET mto_asegurado         = nvl(v_mto_asegurado, 0),
             mto_garantia          = nvl(v_mto_garantia, 0),
             mto_tas_asegurable    = nvl(v_mto_tas_asegurable, 0),
             mto_tas_no_asegurable = nvl(v_mto_tas_no_asegurable, 0),
             
             mto_seg_equ_local        = nvl(v_mto_seg_equ_local, 0),
             mto_gar_equ_local        = nvl(v_mto_gar_equ_local, 0),
             mto_tas_ase_equ_local    = nvl(v_mto_tas_ase_equ_local, 0),
             mto_tas_no_ase_equ_local = nvl(v_mto_tas_no_ase_equ_local, 0)
       WHERE fecha = reg.fecha
         AND nom_referencia = reg.nom_referencia
         AND nro_registro = reg.nro_registro
         AND nro_garantia = reg.nro_garantia;
   END LOOP;
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'ERROR prs_act_mto_garantias: Nro. de garantía: ' ||v_nro_garantia  || SQLERRM);
END;
/

