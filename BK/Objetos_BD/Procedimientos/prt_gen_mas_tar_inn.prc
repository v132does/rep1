CREATE OR REPLACE PROCEDURE IT.PRT_GEN_MAS_TAR_INN (P_COD_CAMPANA       IN CR_CAM_INNOMINADAS.COD_CAMPANA%TYPE,
                                                 P_NRO_IDENTIFICADOR IN CR_CAM_INNOMINADAS.NRO_IDENTIFICADOR%TYPE) IS
   
   v_cod_rub_economico ge_rub_economicos.cod_rub_economico%type := '970107';
   v_cod_per_banco     ge_par_generales.cod_persona%type := fug_obt_per_entidad;
   v_cod_ofi_oficial   ba_oficinas.cod_oficina%type := fug_obt_ofi_oficial(v_cod_per_banco);
   v_nro_solicitud     ta_solicitudes.nro_solicitud%type;
   v_mon_local         ba_monedas.cod_moneda%type := PAG_GEN.FU_OBT_MON_LOCAL;
   v_mot_ret_sol_cli   ge_par_dinamicos.parametro%type := fug_obt_pardinamico('MOT_RET_SOL_CLIENTE');
   v_fec_actual        DATE := pae_cnf.fu_obt_fec_actual(5);
   v_sec_embozo        VARCHAR2(20); 
   
   CURSOR detalle IS
      SELECT a.cod_campana, a.descripcion, b.cod_modulo, b.cod_modalidad, b.lin_credito, b.cod_canal, b.afinidad,
             b.sub_afinidad, b.cod_tip_cierre, b.tip_plastico, b.cantidad
        FROM cr_campanas a, cr_cam_innominadas b
       WHERE a.cod_campana = b.cod_campana
         AND v_fec_actual between fec_inicio and nvl( a.fec_vencimiento, to_date( '31/12/9999', 'DD/MM/YYYY' ) )
         AND nvl( estado, 1 ) = 2
         AND a.cod_campana = p_cod_campana
         AND b.nro_identificador = p_nro_identificador;
   
BEGIN
   FOR cur IN detalle LOOP
      FOR i IN 1..cur.cantidad LOOP
         SELECT s_nro_solicitud.nextval, SUBSTR(fug_obt_nom_entidad,0,13)||' '||lpad(s_sec_tar_innominadas.nextval, 6, 0) 
           INTO v_nro_solicitud, v_sec_embozo 
           FROM dual;
         
         INSERT INTO ta_solicitudes (nro_solicitud, cod_persona, cod_oficina, cod_modulo, cod_modalidad, 
             fec_solicitud, fec_aprobacion, nom_embozado, monto, cod_estado, referencia, 
             observacion, cod_moneda, cod_campana, 
             cod_canal, mto_aprobado, afinidad, sub_afinidad, ind_evaluacion, cod_tip_cierre, cod_rub_economico, tip_plastico)
         VALUES (v_nro_solicitud, v_cod_per_banco, v_cod_ofi_oficial, cur.cod_modulo, cur.cod_modalidad, 
             v_fec_actual, v_fec_actual, v_sec_embozo, cur.lin_credito, 'APR', 1, 
             'Alta Masiva Tarj. Innominadas, campaña: '||cur.descripcion, v_mon_local, cur.cod_campana,
             cur.cod_canal, cur.lin_credito, cur.afinidad, cur.sub_afinidad, 'N', cur.cod_tip_cierre, v_cod_rub_economico, 
             cur.tip_plastico);
         
         INSERT INTO ba_tab_dat_adicionales ( tab_relacion, referencia, parametro, val_parametro)
	 	     VALUES ( 'TA_SOLICITUDES', v_nro_solicitud, 'RET_EXTRACTO', 'S');
         INSERT INTO ba_tab_dat_adicionales ( tab_relacion, referencia, parametro, val_parametro)
	 	 		 VALUES ( 'TA_SOLICITUDES', v_nro_solicitud, 'MOT_RET_EXTRACTO', nvl(v_mot_ret_sol_cli, 5));
      END LOOP; 
   END LOOP; 
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error en PRT_GEN_MAS_TAR_INN. '||sqlerrm);
END PRT_GEN_MAS_TAR_INN;
/

