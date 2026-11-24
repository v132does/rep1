CREATE OR REPLACE TRIGGER IT.TA_CC_CHE_REM_REGISTROS
 AFTER INSERT
 ON CC_CHE_REM_REGISTROS
 FOR EACH ROW

DECLARE
   r_che         cc_che_remitidos_tmp%rowtype;
   r_che_res     cc_che_remitidos_res_tmp%rowtype;
   v_for_archivo varchar2(100) := 'CHE_ENV_PRODEP_REG';
   v_existe      number(1) := 0;
   v_fecha       date := pag_cal.fu_obt_fec_actual(4);
   v_cod_moneda  cj_mov_prodep.cod_moneda%type;
   v_cod_usuario cj_mov_prodep.cod_usuario%type;
   v_nro_doc     cj_mov_prodep.nro_documento%type;
   v_mon_total   cj_mov_prodep.monto%type;
   v_estado      cj_mov_prodep.estado%type;
   v_tip_dato    cc_che_remitidos.tip_dato%type := 1;
   v_nro_lote    cc_che_remitidos.nro_lote%type;
   v_nro_boleta  cj_mov_prodep.nro_referencia%type;
   v_nro_cuenta  cj_mov_prodep.nro_cuenta%type;
   
BEGIN

   IF inserting THEN
      r_che := null;
      --Cabecera
      r_che_res.nro_boleta      := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_RES_TMP',:new.linea,'NRO_BOLETA');          
      r_che_res.monto           := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_RES_TMP',:new.linea,'MONTO'); 
      r_che_res.cod_ofi_origen  := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_RES_TMP',:new.linea,'COD_OFI_ORIGEN');             
      --Detalle
      r_che.cod_banco       := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'COD_BANCO');
      r_che.nro_cuenta      := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'NRO_CUENTA');
      r_che.nro_cheque      := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'NRO_CHEQUE'); 
      r_che.monto           := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'MONTO');
      r_che.fec_giro        := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'FEC_GIRO');          
      r_che.nro_lectora     := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'NRO_LECTORA'); 
      r_che.usu_captura     := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'USU_CAPTURA');
      r_che.cod_bandacm7    := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'COD_BANDACM7');
      r_che.retencion       := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'RETENCION');
      r_che.nro_registro    := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_REMITIDOS_TMP',:new.linea,'NRO_REGISTRO');
      IF r_che.fec_giro > v_fecha THEN
         v_fecha := pag_cal.fu_obt_fec_proxima(4);
      END IF;
      -- verificación si el cheque es en moneda local o extranjera
      IF substr(r_che.cod_bandacm7, 1, 2) = r_che.cod_banco THEN
         IF substr(r_che.cod_bandacm7, 3, 1) <> 0 THEN
            r_che.monto     := r_che.monto/100;
            r_che_res.monto := r_che_res.monto/100;
            v_tip_dato      := 2;   
         END IF;
      ELSE
         IF substr(r_che.cod_bandacm7, 4, 1) <> 0 and substr(r_che.cod_bandacm7, 3, 1) <> 0 THEN
            r_che.monto     := r_che.monto/100;
            r_che_res.monto := r_che_res.monto/100;
            v_tip_dato      := 2;
         END IF;
      END IF; 
      -- se obtienen los datos del movimiento
      prj_obt_dat_mov_prodep(r_che_res.nro_boleta, 
                             null,
                             null,
                             v_cod_usuario,
                             v_cod_moneda, 
                             r_che_res.nro_referencia,
                             v_nro_doc,
                             r_che_res.nro_caja, 
                             v_mon_total,
                             v_estado); 
      IF r_che_res.nro_referencia IS NULL THEN
         v_mon_total := r_che_res.monto;
         prj_obt_dat_mov_prodep(r_che_res.nro_boleta, 
                                null,
                                null,
                                v_cod_usuario,
                                v_cod_moneda, 
                                r_che_res.nro_referencia,
                                v_nro_doc,
                                r_che_res.nro_caja, 
                                v_mon_total,
                                v_estado);
      END IF;   
      
      IF v_tip_dato = 1 THEN
         BEGIN
           SELECT 1  
             INTO v_existe
             FROM cc_che_remitidos_res_tmp
            WHERE nro_boleta = r_che_res.nro_boleta
              AND monto = r_che_res.monto;
         EXCEPTION
           WHEN others THEN
             v_existe := 0;
         END;
         IF pae_cnf.g_nro_secuencia IS NULL THEN
            pae_cnf.g_nro_secuencia := -9999;
         END IF;
         v_nro_lote := pae_cnf.g_nro_secuencia;         
         --- Se inserta la cabecera si aún no se cargó la boleta
         IF v_existe = 0 THEN                                                 
            v_nro_lote := pae_cnf.fu_obt_sig_secuencia;
            INSERT INTO cc_che_remitidos_res_tmp
               (fecha, cod_oficina, nro_referencia, nro_boleta, 
                monto, nro_lote, nro_caja, cod_ofi_origen)
             VALUES
               (v_fecha, r_che_res.cod_oficina, r_che_res.nro_referencia, r_che_res.nro_boleta, r_che_res.monto,
                v_nro_lote, nvl(r_che_res.nro_caja, 998), r_che_res.cod_ofi_origen);             
         END IF;
      ELSE
         v_nro_lote    := null;
         v_nro_boleta  := r_che_res.nro_boleta;
         v_nro_cuenta  := r_che_res.nro_referencia;
      END IF; 
      
      INSERT INTO cc_che_remitidos_tmp
         (nro_linea, cod_banco, monto, nro_cheque, nro_cuenta, cod_oficina, fecha, nro_boleta,
          nro_referencia, nro_lote, fec_giro, nro_lectora, usu_captura, cod_bandacm7, retencion,
          nro_caja, cod_ofi_origen, nro_registro)
      VALUES
         (r_che.nro_linea, r_che.cod_banco, r_che.monto, r_che.nro_cheque, r_che.nro_cuenta,
          r_che.cod_oficina, v_fecha, v_nro_boleta, v_nro_cuenta, v_nro_lote, r_che.fec_giro,
          r_che.nro_lectora, r_che.usu_captura, r_che.cod_bandacm7, r_che.retencion,
          nvl(r_che_res.nro_caja, 998), r_che_res.cod_ofi_origen, r_che.nro_registro);

   END IF;
END;
/
