CREATE OR REPLACE PROCEDURE IT.PRC_INS_MOT_CHE_RECHAZADOS
 (p_fec_proceso      in cc_che_rechazados_tmp.fec_proceso%type,
  p_nro_cheque       in cc_che_remitidos.nro_cheque%type,
  p_cod_bco_emisor   in cc_che_remitidos.cod_banco%type,
  p_cta_libradora    in cc_che_remitidos.nro_cuenta%type,
  p_cod_cau_dev_det  in cc_che_rechazados_tmp.cod_cau_dev_bcp_det%type
 ) IS
  v_longitud        number(2);
  v_posicion        number(2) := 1;
  v_cod_cau_dev     cc_che_rechazados_det.cod_cau_devolucion%type;
  v_cod_cau_dev_bcp number(2);
BEGIN
  DELETE cc_che_rechazados_det d
   WHERE d.fec_proceso = p_fec_proceso
     AND d.nro_cheque  = p_nro_cheque
     AND d.cod_bco_emisor = p_cod_bco_emisor
     AND d.cta_libradora = p_cta_libradora;
  v_longitud := nvl(round(length(p_cod_cau_dev_det)/2), 0);        
  FOR i in 1..v_longitud LOOP
      v_cod_cau_dev_bcp := substr(p_cod_cau_dev_det, v_posicion, 2);
      BEGIN
        SELECT MAX(z.cod_causa)
          INTO v_cod_cau_dev
          FROM ge_par_causales z
         WHERE z.parametro = 'COD_DEV_BCP' 
           AND z.val_parametro = v_cod_cau_dev_bcp;
      EXCEPTION
         WHEN OTHERS THEN
           v_cod_cau_dev := null;   
      END;  
      IF v_cod_cau_dev IS NOT NULL THEN
        INSERT INTO cc_che_rechazados_det
          (fec_proceso, nro_cheque, cta_libradora, cod_bco_emisor, 
           cod_cau_devolucion, cod_cau_dev_bcp)
        VALUES
          (p_fec_proceso, p_nro_cheque, p_cta_libradora, p_cod_bco_emisor,
           v_cod_cau_dev, v_cod_cau_dev_bcp);
      END IF;     
      v_posicion := v_posicion + 2;   
  END LOOP;   
EXCEPTION
  WHEN OTHERS THEN
     raise_application_error(-20099, 'Error al insertar los motivos de rechazos secundarios. - '||sqlerrm);
END;
/

