CREATE OR REPLACE FUNCTION IT.FUC_OBT_MOT_RCH_SECUNDARIO
 (p_nro_cuenta     in varchar2,
  p_nro_cheque     in cc_che_remitidos_det.nro_cheque%type,
  p_fecha          in date,
  p_cod_banco      in cc_che_rechazados_det.cod_bco_emisor%type default null,
  p_tipo           in varchar2 default 'R'--Recibidos
 )
 RETURN VARCHAR2
 IS
   v_motivo     varchar2(8000);
   --
   CURSOR c_motrch IS
     SELECT cod_causa
       FROM cc_che_devueltos_det
      WHERE fecha      = p_fecha
        AND nro_cuenta = p_nro_cuenta
        AND nro_cheque = p_nro_cheque
      ORDER BY cod_cau_dev_bcp;
   --
   CURSOR c_motdev IS
     SELECT r.cod_cau_devolucion
       FROM cc_che_rechazados_det r
      WHERE r.fec_proceso    = p_fecha
        AND r.nro_cheque     = p_nro_cheque
        AND r.cta_libradora  = p_nro_cuenta
        AND r.cod_bco_emisor = p_cod_banco
      ORDER BY cod_cau_dev_bcp;      
BEGIN
  IF p_tipo = 'R' THEN
     FOR m in c_motrch LOOP
         v_motivo := v_motivo||lpad(nvl(fug_obt_parcausales(m.cod_causa, 'COD_DEV_BCP'), '01'), 2, '0');
     END LOOP;
  ELSE 
     FOR m in c_motdev LOOP
         IF v_motivo IS NULL THEN
            v_motivo := fug_obt_des_causa(m.cod_cau_devolucion);
         ELSE   
            v_motivo := v_motivo||' - '||fug_obt_des_causa(m.cod_cau_devolucion);
         END IF;
     END LOOP; 
  END IF;             

  return v_motivo;

EXCEPTION
   WHEN OTHERS THEN
     IF sqlcode < -20000 THEN
         raise;
     ELSE
        raise_application_error(-20000,'Error en FUC_OBT_MOT_RCH_SECUNDARIO : ' || sqlerrm);
     END IF;
END;
/

