CREATE OR REPLACE PROCEDURE IT.PRL_GEN_SAL_POSICIONES
 IS
--- OBS: Primer Proceso del cierre de Cambios
   v_fec_actual  ge_calendarios.fec_actual%type;
   v_error       varchar2(250);
   W_MONEDA      ba_monedas.cod_moneda%type;
   W_CDOFICI     ba_oficinas.cod_oficina%type;
   W_COTEFE      ge_cotizaciones.val_conversion%type;
   W_COTNEF      ge_cotizaciones.val_conversion%type;
   W_EFECOM      lc_sal_diarios.mto_pos_com_efe_ant%type;
   W_EFEVEN      lc_sal_diarios.mto_pos_vta_efe_ant%type;
   W_NEFCOM      lc_sal_diarios.mto_pos_com_nef_ant%type;
   W_NEFVEN      lc_sal_diarios.mto_pos_vta_nef_ant%type;
   CURSOR C_CURSOR IS
      SELECT COD_OFICINA,COD_MONEDA,MTO_POS_COM_EFE_ANT,MTO_POS_VTA_EFE_ANT,MTO_POS_COM_NEF_ANT,
             MTO_POS_VTA_NEF_ANT
        FROM GE_PAR_GENERALES P, LC_SAL_DIARIOS S
       WHERE COD_MONEDA <> COD_MON_LOCAL
         AND (MTO_POS_COM_EFE_ANT > 0 OR MTO_POS_VTA_EFE_ANT > 0 OR MTO_POS_COM_NEF_ANT > 0
               OR MTO_POS_VTA_NEF_ANT > 0
               OR COD_MONEDA IN (SELECT COD_MONEDA FROM GE_MOVIMIENTOS
                                   WHERE ESTADO IN ('N','H')
                                     AND REVERSADO = 'N'
                                     and cod_mod_padre = 7));
BEGIN
   --- Recuperar fecha del modulo
   v_fec_actual := pag_cal.fu_obt_fec_actual(7);
   --- Eliminar tabla de saldos de posiciones
   delete lc_sal_posiciones;
   --Se reemplaza porque hace commit implicito y no puede reprocesarse
   --sql_util.ejecute_dml('truncate table lc_sal_posiciones', v_error);   
   
   if v_error is not null then
      raise_application_error(-20000,
      'Elimina lc_sal_posiciones '||v_error);
   end if;
   --- Generar posiciones
   IF C_CURSOR%ISOPEN THEN
      CLOSE C_CURSOR;
   END IF;
   ------------------------ APERTURA DEL CURSOR ---------------------------
   OPEN C_CURSOR;
   LOOP
      FETCH C_CURSOR INTO W_CDOFICI,W_MONEDA,W_EFECOM,W_EFEVEN,W_NEFCOM,
                          W_NEFVEN;
      EXIT WHEN C_CURSOR%NOTFOUND;
      --- Recuperar cotizacion de conversion efectivo del Banco Central dia anterior
      w_cotefe := fug_obt_cotizacion(w_moneda,v_fec_actual-1);
      --- Recuperar cotizacion de conversion del Banco Central dia anterior
      w_cotnef := fug_obt_cotizacion(w_moneda,v_fec_actual-1);
      --- Insertar saldo de posiciones
      INSERT INTO LC_SAL_POSICIONES(COD_OFI_CAMBIO,COD_MONEDA,TIP_POSICION,MTO_EFE_COMPRA,
                           COT_EFECTIVO,COT_NO_EFECTIVO,MTO_EFE_VENTA,MTO_NEF_COMPRA,MTO_NEF_VENTA)
                    VALUES(W_CDOFICI,W_MONEDA,'E',W_EFECOM,W_COTEFE,W_COTNEF,
                           W_EFEVEN,W_NEFCOM,W_NEFVEN);
      INSERT INTO LC_SAL_POSICIONES(COD_OFI_CAMBIO,COD_MONEDA,TIP_POSICION,MTO_EFE_COMPRA,
                           COT_EFECTIVO,COT_NO_EFECTIVO,MTO_EFE_VENTA,MTO_NEF_COMPRA,MTO_NEF_VENTA)
                    VALUES(W_CDOFICI,W_MONEDA,'O',W_EFECOM,W_COTEFE,W_COTNEF,
                           W_EFEVEN,W_NEFCOM,W_NEFVEN);
   END LOOP;
   CLOSE C_CURSOR;
END;
/

