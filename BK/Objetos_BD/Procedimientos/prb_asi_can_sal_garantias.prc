CREATE OR REPLACE PROCEDURE IT.PRB_ASI_CAN_SAL_GARANTIAS IS
/*
|  Creado por : tys en Bco. Regional
|  Finalidad  : Generar asiento de cancelacion de saldos de garantias.
|               Quitar cuando se implemente la contabilizacion de garantias en ITGF
*/
  v_fec_actual     DATE := pag_cal.fu_obt_fec_actual(2);
  v_nro_asiento    cb_asientos.nro_asiento%TYPE;
  v_tot_control    cb_asientos.tot_control%TYPE;
  v_nro_linea      cb_asientos_det.nro_linea%TYPE;
  v_mto_mon_local  cb_asientos_det.mto_mon_local%TYPE;
  v_mto_mon_rubro  cb_asientos_det.mto_mon_rubro%TYPE;
  v_val_cotizacion cb_asientos_det.val_cotizacion%TYPE;
  v_tip_movimiento cb_asientos_det.tip_movimiento%TYPE;

  -- Cursor de Sucursales
  CURSOR c_oficinas IS
    SELECT cod_oficina
      FROM ba_oficinas
     ORDER BY cod_oficina;

  -- Cursor de Saldos de Garantias
  CURSOR c_sal_garantias (p_cod_oficina NUMBER) IS
    SELECT so.cod_oficina, so.cod_rubro, r.descripcion, r.cod_moneda,
           so.sal_mon_loc_ant + so.deb_mon_local - so.cre_mon_local sal_mon_local,
           so.sal_mon_rub_ant + so.deb_mon_rubro - so.cre_mon_rubro sal_mon_rubro
      FROM cb_rubros r, cb_sal_oficinas so
     WHERE r.cod_rubro = so.cod_rubro
       AND so.sal_mon_loc_ant + so.deb_mon_local - so.cre_mon_local <> 0
       AND r.imputable = 'S'
       AND (r.cod_rubro like '5101065104001__' OR 
            r.cod_rubro like '5101065104002__' OR 
            r.cod_rubro like '5101065104004__' OR 
            r.cod_rubro like '5101065108001__' OR 
            r.cod_rubro like '5101065108002__' OR 
            r.cod_rubro like '5101065301001__' OR 
            r.cod_rubro like '5101065301002__' OR 
            r.cod_rubro like '5201065202001__' OR 
            r.cod_rubro like '5201065202002__' OR 
            r.cod_rubro like '5201065202004__' OR 
            r.cod_rubro like '5201065402001__' OR 
            r.cod_rubro like '5201065402002__' OR 
            r.cod_rubro like '5201065402003__' OR 
            r.cod_rubro like '5201065402004__')
       AND so.cod_oficina = p_cod_oficina
     ORDER BY so.cod_oficina, r.cod_moneda, abs(so.sal_mon_loc_ant), so.cod_rubro;

BEGIN
  v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');

  FOR ofi IN c_oficinas LOOP
    v_nro_asiento := v_nro_asiento + 1;
    v_tot_control := 0;
    v_nro_linea   := 0;

    -- Genera detalle de asientos
    FOR sal IN c_sal_garantias(ofi.cod_oficina) LOOP
      v_nro_linea := v_nro_linea + 1;
      
      IF sal.sal_mon_local > 0 THEN
        v_tip_movimiento := 'C';
        v_mto_mon_local  := sal.sal_mon_local;
        v_mto_mon_rubro  := sal.sal_mon_rubro;
      ELSE
        v_tip_movimiento := 'D';
        v_mto_mon_local  := sal.sal_mon_local * -1;
        v_mto_mon_rubro  := sal.sal_mon_rubro * -1;
      END IF;
          
      IF nvl(sal.sal_mon_rubro,0) <> 0 THEN
        v_val_cotizacion := round(v_mto_mon_local / v_mto_mon_rubro, 8);
      ELSE
        v_val_cotizacion := NULL;
      END IF;

      -- Inserta el detalle de asiento
      INSERT INTO cb_asientos_det
        (cod_oficina, nro_asiento, nro_linea, cod_rubro, 
         mto_mon_local, mto_mon_rubro, tip_movimiento, referencia, 
         descripcion, protegido, actualizado, val_cotizacion, distribuido, fecha)
      VALUES
        (sal.cod_oficina, v_nro_asiento, v_nro_linea, sal.cod_rubro,
         v_mto_mon_local, v_mto_mon_rubro, v_tip_movimiento, NULL,
         'Canc. Saldo Garantia', 'N', 'N', v_val_cotizacion, 'N', v_fec_actual);
      
      v_tot_control := v_tot_control + v_mto_mon_local;
    END LOOP;

    -- Inserta la cabecera de asientos
    IF v_tot_control <> 0 THEN
      INSERT INTO cb_asientos
        (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo,
         cod_modalidad, tot_control, actualizado, reversado, cod_ofi_origen,
         ofi_integrada, confirmado)
      VALUES
        (ofi.cod_oficina, v_nro_asiento, USER, v_fec_actual, 2, 21,
         v_tot_control, 'N', 'N', NULL, 'N', 'S');
    END IF;

  END LOOP;

  -- Actualiza el siguiente nro de asiento
  prg_act_par_dinamico('SIG_NRO_ASIENTO', NULL, NULL, NULL, NULL, v_nro_asiento + 1);

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, 'Error en PRB_ASI_CAN_SAL_GARANTIAS.' || chr(13) || SQLERRM);
END PRB_ASI_CAN_SAL_GARANTIAS;
/

