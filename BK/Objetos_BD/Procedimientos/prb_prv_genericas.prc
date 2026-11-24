CREATE OR REPLACE PROCEDURE IT.PRB_PRV_GENERICAS
(P_FECHA IN DATE,
 P_TIP_OPERACION IN VARCHAR2,
 P_GRU_RUBRO     IN NUMBER,
 P_MONEDA        IN VARCHAR2,
 P_MONTO         IN NUMBER,
 P_CONCEPTO      IN VARCHAR2)
IS
  v_fcdehoy              date;
  v_cod_mon_local        ba_monedas.cod_moneda%type;
  v_cotizacion           ge_cotizaciones.val_conversion%type;
  v_cod_ofi              ba_oficinas.cod_oficina%type;

  v_rub_generica         cb_rubros.cod_rubro%type;
  v_rub_perdida          cb_rubros.cod_rubro%type;
  v_rub_ganancia         cb_rubros.cod_rubro%type;
  v_rub_credito          cb_rubros.cod_rubro%type;
  v_rub_debito           cb_rubros.cod_rubro%type;
  v_cod_mon_rub_cre      cb_rubros.cod_moneda%type;
  v_cod_mon_rub_deb      cb_rubros.cod_moneda%type;
  v_rub_bol_cre          cb_rubros.cod_rubro%type;
  v_rub_bol_deb          cb_rubros.cod_rubro%type;
  v_cod_mon_rub_cre_bol  cb_rubros.cod_moneda%type;
  v_cod_mon_rub_deb_bol  cb_rubros.cod_moneda%type;
  v_cod_gru_rubro        cb_gru_rubros.cod_gru_rubro%type;
  v_nro_asiento           cb_asientos.nro_asiento%type;
-- Variables de registro
  rg_asis                cb_asientos_det%rowtype;

--*
--*   PROCEDIMIENTO PRINCIPAL
--*
BEGIN
 v_fcdehoy       := pag_cal.fu_obt_fec_actual(2);    -- fecha de hoy
 v_cod_mon_local := pag_gen.fu_obt_mon_local;
 v_cotizacion    := pag_gen.FU_OBT_COTIZACION(P_MONEDA,P_FECHA);
 v_cod_ofi       := fug_obt_ofi_matriz;
 v_cod_gru_rubro := 7; --Corresponde al C?digo de Grupo de Rubro definido para"RUBROS PARA BOLETEO OPERACIONES A LIQUIDAR DIA ANTERIOR"
 --Obtener los rubros asociados al grupo
 Begin
   select r.cod_rub_generica, r.cod_rub_perdida, r.cod_rub_ganancia
     into v_rub_generica, v_rub_perdida, v_rub_ganancia
     from cb_rub_genericas r
    where r.cod_gru_rubro = p_gru_rubro
      and r.cod_moneda    = p_moneda;
 Exception
   when others then
     raise_application_error(-20000,'No se han podido obtener Rubros para el Grupo : '||p_gru_rubro||' y la moneda : '||p_moneda||' Error : '||sqlerrm);
 End;

 --Asignar valores generales para registro de asientos
 rg_asis.usu_insercion     := user;
 rg_asis.fecha           := v_fcdehoy;
 rg_asis.fec_valor       := P_FECHA;
 --
 /*  Constitucion : Previsi?n contra P?rdida
     Retrocesi?n  : P?rdida contra Previsi?n
     Desafectaci?n : P?rdida contra Ganancia
  */
 If p_tip_operacion = 'C' then  -- Constituci?n
    v_rub_credito := v_rub_generica;
    v_rub_debito  := v_rub_perdida;
 Elsif p_tip_operacion = 'R' then  -- Retrocesi?n
    v_rub_credito := v_rub_perdida;
    v_rub_debito  := v_rub_generica;
 Elsif p_tip_operacion = 'D' then -- Desafectaci?n
    v_rub_credito := v_rub_ganancia;
    v_rub_debito  := v_rub_perdida;
 End if;
--Busca codigo de moneda del rubro
 Begin
   select rb.cod_moneda
     into v_cod_mon_rub_cre
     from cb_rubros rb
    where rb.cod_rubro = v_rub_credito;
 Exception
   when no_data_found then
     v_cod_mon_rub_cre := v_cod_mon_local;
   when others then
     raise_application_error(-20000,'Error en la busqueda del c?digo de moneda del rubro '||v_rub_credito||' '||sqlerrm);
 End;
 Begin
   select rb.cod_moneda
     into v_cod_mon_rub_deb
     from cb_rubros rb
    where rb.cod_rubro = v_rub_debito;
 Exception
   when no_data_found then
     v_cod_mon_rub_deb := v_cod_mon_local;
   when others then
     raise_application_error(-20000,'Error en la busqueda del c?digo de moneda del rubro '||v_rub_debito||' '||sqlerrm);
 End;

  BEGIN
     v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
     prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, (v_nro_asiento + 1));
 --Inserta la cabcera del Asiento
  INSERT INTO cb_asientos
          (cod_oficina, nro_asiento, cod_usuario, fecha,
           cod_modulo, cod_modalidad, tot_control,
           actualizado, reversado, cod_ofi_origen, ofi_integrada,
           confirmado, fec_valor)
       VALUES
          (v_cod_ofi, v_nro_asiento, rg_asis.usu_insercion , P_FECHA,
           2, 21, P_MONTO,
           'N','N',v_cod_ofi, 'N', 'S', P_FECHA);
   --Inserta el D?bito del Asiento
   insert into cb_asientos_det
               (fecha, cod_oficina, nro_asiento, nro_linea,
                cod_rubro, tip_movimiento,
                mto_mon_rubro,
                mto_mon_local,
                descripcion, referencia,
                protegido, actualizado,
                val_cotizacion,
                distribuido, ref_movimiento, usu_insercion,
                fec_insercion,usu_modificacion,fec_modificacion,
                fec_valor)
   values
             (P_FECHA,v_cod_ofi, v_nro_asiento, 1,
              v_rub_debito, 'D',
              decode(v_cod_mon_rub_deb,v_cod_mon_local,0,P_MONTO),
              decode(P_MONEDA,v_cod_mon_local,P_MONTO,(P_MONTO*v_cotizacion)),
              P_CONCEPTO, 'PREV. GEN.',
              'N', 'N',
              decode(P_MONEDA,v_cod_mon_local,NULL,v_cotizacion),
              'N', NULL, rg_asis.usu_insercion,
              rg_asis.fecha, rg_asis.usu_insercion, rg_asis.fecha,
              rg_asis.fec_valor);
    --Inserta el Cr?dito del Asiento
     insert into cb_asientos_det
               (fecha, cod_oficina, nro_asiento, nro_linea,
                cod_rubro, tip_movimiento,
                mto_mon_rubro,
                mto_mon_local,
                descripcion,
                referencia,
                protegido, actualizado,
                val_cotizacion,
                distribuido, ref_movimiento, usu_insercion,
                fec_insercion,usu_modificacion,fec_modificacion,
                fec_valor)
   values
             (P_FECHA,v_cod_ofi, v_nro_asiento, 2,
              v_rub_credito, 'C',
              decode(v_cod_mon_rub_cre,v_cod_mon_local,0,P_MONTO),
              decode(P_MONEDA,v_cod_mon_local,P_MONTO,(P_MONTO*v_cotizacion)),
               P_CONCEPTO, 'PREV. GEN.',
              'N', 'N',
               decode(P_MONEDA,v_cod_mon_local,NULL,v_cotizacion),
              'N', NULL,rg_asis.usu_insercion,
              rg_asis.fecha, rg_asis.usu_insercion, rg_asis.fecha,
              rg_asis.fec_valor);
  END;
--Realiza asiento de boleteo
  IF v_cod_mon_rub_cre <> v_cod_mon_rub_deb then
       begin
        select re.cod_rubro,rs.cod_moneda
        into  v_rub_bol_cre,v_cod_mon_rub_cre_bol
        from cb_gru_rubros_det re,cb_rubros rs
        where re.cod_gru_rubro = v_cod_gru_rubro
        and   re.cod_rubro     =  rs.cod_rubro
        and   rs.cod_moneda    =  v_cod_mon_rub_deb; -- tom? la moneda de cr?dito para cuadrar en moneda Extranjera.
        Exception
        when others then
             raise_application_error(-20000,'Error en la busqueda del rubro para boleteo Cr?ito'||' '||sqlerrm);
      end;
      begin
        select re.cod_rubro,rs.cod_moneda
        into  v_rub_bol_deb,v_cod_mon_rub_deb_bol
        from cb_gru_rubros_det re,cb_rubros rs
        where re.cod_gru_rubro = v_cod_gru_rubro
        and   re.cod_rubro     =  rs.cod_rubro
        and   rs.cod_moneda    =  v_cod_mon_rub_cre;-- tom? la moneda de d?bito para cuadrar en moneda Extranjera.
        Exception
        when others then
             raise_application_error(-20000,'Error en la busqueda del rubro para boleteo D?bito'||' '||sqlerrm);
      end;
      --Inserta el D?bito del boleteo del Asiento
   insert into cb_asientos_det
               (fecha, cod_oficina, nro_asiento, nro_linea,
                cod_rubro, tip_movimiento,
                mto_mon_rubro,
                mto_mon_local,
                descripcion, referencia,
                protegido, actualizado,
                val_cotizacion,
                distribuido, ref_movimiento, usu_insercion,
                fec_insercion,usu_modificacion,fec_modificacion,
                fec_valor)
   values
             (P_FECHA,v_cod_ofi, v_nro_asiento, 3,
              v_rub_bol_deb, 'D',
              decode(v_cod_mon_rub_deb_bol,v_cod_mon_local,0,P_MONTO),
              decode(P_MONEDA,v_cod_mon_local,P_MONTO,(P_MONTO*v_cotizacion)),
              P_CONCEPTO, 'PREV. GEN.',
              'N', 'N',
              decode(P_MONEDA,v_cod_mon_local,NULL,v_cotizacion),
              'N', NULL, rg_asis.usu_insercion,
              rg_asis.fecha, rg_asis.usu_insercion, rg_asis.fecha,
              rg_asis.fec_valor);
    --Inserta el Cr?dito del boleteo del Asiento
     insert into cb_asientos_det
               (fecha, cod_oficina, nro_asiento, nro_linea,
                cod_rubro, tip_movimiento,
                mto_mon_rubro,
                mto_mon_local,
                descripcion,
                referencia,
                protegido, actualizado,
                val_cotizacion,
                distribuido, ref_movimiento, usu_insercion,
                fec_insercion,usu_modificacion,fec_modificacion,
                fec_valor)
   values
             (P_FECHA,v_cod_ofi, v_nro_asiento, 4,
              v_rub_bol_cre, 'C',
              decode(v_cod_mon_rub_cre_bol,v_cod_mon_local,0,P_MONTO),
              decode(P_MONEDA,v_cod_mon_local,P_MONTO,(P_MONTO*v_cotizacion)),
               P_CONCEPTO, 'PREV. GEN.',
              'N', 'N',
               decode(P_MONEDA,v_cod_mon_local,NULL,v_cotizacion),
              'N', NULL,rg_asis.usu_insercion,
              rg_asis.fecha, rg_asis.usu_insercion, rg_asis.fecha,
              rg_asis.fec_valor);
  END IF;
Exception
  WHEN OTHERS THEN
     raise_application_error(-20000, 'Error al generar movimientos de Previsiones Gen?ricas. Error : '||sqlerrm);
END;
/

