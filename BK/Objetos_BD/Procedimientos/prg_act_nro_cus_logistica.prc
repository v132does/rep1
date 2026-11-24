CREATE OR REPLACE PROCEDURE IT.prg_act_nro_cus_logistica IS

v_fec_insercion ge_cuentas.fec_insercion%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

  CURSOR c_log IS
  SELECT *
    FROM ge_nom_logistica_tmp a
   WHERE a.cod_estado <> 'I'
     AND (a.fec_apertura = v_fec_insercion OR a.fec_apertura = pag_cal.fu_obt_fec_ant_hab(v_fec_insercion,a.cod_ofi_origen));

  VCODIGO  Number(6); --para almacenar el codigo siguiente del nro_cus

BEGIN
  BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
  
  --obtenemos el siguiente nro_lote para insertar
  Begin
     Select MAX(nvl(g.nro_cus,0)) + 1
       Into VCODIGO
       From ge_nom_logistica_tmp g;
  Exception
     When NO_DATA_FOUND Then
          VCODIGO := 1;
  End;
  
  FOR c IN c_log LOOP
    
    begin
      update ge_nom_logistica_tmp n
         set n.cod_estado = 'N',
             n.nro_cus = VCODIGO
       where n.nro_cuenta = c.nro_cuenta
         and n.nro_guia = c.nro_guia
         and n.cod_estado <> 'I'
         and (n.fec_apertura = v_fec_insercion OR n.fec_apertura =  pag_cal.fu_obt_fec_ant_hab(v_fec_insercion,n.cod_ofi_origen));
    exception
      when others then
        RAISE_APPLICATION_ERROR(-20000, 'Error al actualizar en GE_NOM_LOGISTICA_TMP. Nro. cuenta: '||c.nro_cuenta||' - '||sqlerrm);
    end;
    
  END LOOP;
END;
/

