create or replace procedure it.PRH_INS_GTH_MOVIMIENTOS is
  --18/06/2013-DI-PN:
  /*Cursor que trae los usuarios de la tabla softrh.RHMITGF10
  con el fin de validar su existencia en la tabla ba_usuarios*/
 /* cursor cuh_rec_usu_softrh is
    select distinct REPLACE(upper(AUSRID), CHR(32), '') cod_usuario
      from softrh.RHMITGF10;

  cursor cuh_rec_dat_gth is
    select A.CODOFICINA COD_OFICINA,
           NRODOCUMENTO COD_AREA,
           SUM(nvl(CANPERSONA, 0)) CANT_PERSONAS,
           pag_cal.FU_OBT_FEC_ACTUAL(14) fecha
      from softrh.RHMITGF10 a
     where codtransaccion = 1400
     group by a.codoficina, NRODOCUMENTO, fechaitgf;

  cursor cuh_rec_gth_rhmitgf10 is
    select pag_cal.FU_OBT_FEC_ACTUAL(14) fecha,
           REPLACE(upper(A.AUSRID), CHR(32), '') USUARIO,
           A.NROSECUENCIA NRO_SECUENCIA,
           a.fechaitgf FEC_VALOR,
           A.MONTO,
           REPLACE(a.NROCUENTA, CHR(32), '') NRO_CUENTA,
           UPPER(REPLACE(A.CODMONEDA, CHR(32), '')) COD_MONEDA,
           A.CODOFICINA COD_OFICINA,
           A.CODERROR COD_ERROR,
           A.ESTCUENTA EST_CUENTA,
           A.ESTADO ESTADO,
           A.CODOFIORIGEN COD_OFI_ORIGEN,
           A.CONCEPTO CONCEPTO,
           A.REVERSADO REVERSADO,
           REPLACE(A.CODUSUREVERSION, CHR(32), '') COD_USU_REVERSION,
           REPLACE(A.HORREVERSION, CHR(32), '') HOR_REVERSION,
           A.EMIAVISO EMI_AVISO,
           A.CODTRAPADRE COD_TRA_PADRE,
           14 COD_MOD_PADRE,
           141 COD_MAD_PADRE,
           A.CODTRANSACCION COD_TRANSACCION,
           14 COD_MODULO,
           141 COD_MODALIDAD,
           A.NRODOCUMENTO NRO_DOCUMENTO,
           decode(A.NRODOCUMENTO2, 0, null, A.NRODOCUMENTO2) NRO_DOCUMENTO2,
           decode(A.NRODOCUMENTO3, 0, null, A.NRODOCUMENTO3) NRO_DOCUMENTO3,
           decode(A.NRODOCUMENTO4, 0, null, A.NRODOCUMENTO4) NRO_DOCOUMENTO4,
           A.REFERENCIA REFERENCIA
      from softrh.RHMITGF10 a;

  v_exi_usuario       varchar2(1);
  v_ctl_monto         varchar2(1);
  v_ult_dia_mes_habil date;
  v_exi_can_per_gasto varchar2(1);
  v_nro_secuencia     number(4) := 0;
  v_hora              GE_MOVIMIENTOS.HORA%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_cod_empleado ba_personas.cod_persona%type;
  Procedure lp_imp_legajos is
    -- Proceso para importar los datos de legajos desde GTH a ITGF.
    -- Legajos inexistentes en ITGF(cod_persona existentes en ba_personas y no rh_empleados).
    -- Agregado: 04/08/2014 -- EGC --
    cursor cuh_rec_dat_legajos is
      select a.funcnrocliente cod_persona,
             '01' cod_per_empresa,
             b.uniorgempiddep cod_oficina,
             1 cod_cen_costo,
             a.funcfrmpag tipo,
             substr(trim(c.cardes),1,40) cargo,
             '' titulo,
             d.personrobaj nro_baja,
             a.funclesion ind_jub_ips,
             a.funcnroase nro_ips,
             '' nro_caja,
             0 sal_base,
             'GS' cod_moneda,
             1 cod_turno,
             nvl(d.persocat,2) cod_cat_empleado,
             1 cod_sal_minimo,
             lpad(a.funcbanco, 14, '0') nro_cta_asociada,
             '' nro_tarjeta,
             a.funcfrmpag fre_liquidacion,
             a.funcfecing fec_ingreso,
             a.funcfecsal fec_egreso,
             f.funcfecfincnt fec_fin_contrato,
             a.funcgrusan gru_sanguineo,
             '' ind_seg_privado,
             '' cod_ent_seguro,
             '' observacion
        from softrh.rhemple    a, --Funcionarios.
             softrh.bamuog     b, --Unidades Organizacionales.
             softrh.rhmcrg     c, --Cargos.
             softrh.rhm100     d, --Personas.
             softrh.empm100    e, --Empresa.
             softrh.rhmemple10 f --Contratos.
       where a.uniorgcod = b.uniorgcod
         and a.empid = b.empid
         and a.empid = c.empid(+)
         and a.carcod = c.carcod(+)
         and a.funcnro = d.personro
         and a.empid = e.empid
         and a.empid = f.empid(+)
         and a.funcnro = f.funcnro(+)
         -- and a.funccctid = f.funccntid(+) --DYDMR-12387
         and a.funcnrocliente is not null
            -- Codigos de personas que aun no existen en RH_EMPLEADOS
         and a.funcnrocliente not in
             (select distinct cod_persona from rh_empleados)
         and a.funcnrocliente in
             (select distinct cod_persona from ba_personas)
            -- Aun no han sido dado de baja.
         and a.funcfecsal is null;
      
    */     
  begin
    /*for i in cuh_rec_dat_legajos loop
      v_cod_empleado := i.cod_persona;
      insert into rh_empleados
        (cod_persona,
         cod_per_empresa,
         cod_oficina,
         cod_cen_costo,
         tipo,
         cargo,
         titulo,
         nro_baja,
         nro_ips,
         ind_jub_ips,
         nro_caja,
         sal_base,
         cod_moneda,
         cod_turno,
         cod_cat_empleado,
         cod_sal_minimo,
         nro_cta_asociada,
         nro_tarjeta,
         fre_liquidacion,
         fec_ingreso,
         fec_egreso,
         fec_fin_contrato,
         gru_sanguineo,
         ind_seg_privado,
         cod_ent_seguro)
      values
        (i.cod_persona,
         i.cod_per_empresa,
         i.cod_oficina,
         i.cod_cen_costo,
         i.tipo,
         i.cargo,
         i.titulo,
         i.nro_baja,
         i.nro_ips,
         i.ind_jub_ips,
         i.nro_caja,
         i.sal_base,
         i.cod_moneda,
         i.cod_turno,
         i.cod_cat_empleado,
         i.cod_sal_minimo,
         i.nro_cta_asociada,
         i.nro_tarjeta,
         i.fre_liquidacion,
         i.fec_ingreso,
         i.fec_egreso,
         i.fec_fin_contrato,
         i.gru_sanguineo,
         i.ind_seg_privado,
         i.cod_ent_seguro);
    end loop;
    /*Graba los nuevos legajos*/
 /*   commit;
  
  exception
    when others then
      raise_application_error(-20000, 'Error al realizar la importacion de Legajos. '||v_cod_empleado||'-' || sqlerrm);
  end;
begin

  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;
  -- Importacion de Nuevos Legajos
  lp_imp_legajos;
  -- 
  for u in cuh_rec_usu_softrh loop
    BEGIN
      select distinct 'S'
        into v_exi_usuario
        from ba_usuarios
       where cod_usuario = u.cod_usuario;
    EXCEPTION
      WHEN OTHERS THEN
        v_exi_usuario := 'N';
    END;
    IF NVL(v_exi_usuario, 'N') = 'N' THEN
      raise_application_error(-20000, 'No se encuentra el Codigo de Usuario: ' || u.cod_usuario);
    END IF;
  end loop;

  BEGIN
    select distinct 'S'
      into v_ctl_monto
      from softrh.RHMITGF10
     where nvl(monto, 0) <= 0;
  EXCEPTION
    WHEN OTHERS THEN
      v_ctl_monto := 'N';
  END;

  IF NVL(v_ctl_monto, 'N') = 'S' THEN
    raise_application_error(-20000, 'El Monto de la Operacion no puede ser igual a cero o negativo');
  END IF;

  BEGIN
    select ult_dia_mes_habil
      into v_ult_dia_mes_habil
      from ge_calendarios
     WHERE COD_MODULO = '14';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000, 'No se encuentra el ultimo dia del mes habil.');
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al buscar el ultimo dia del mes habil. ' || sqlerrm);
  END;

  --18/06/2013-DI-PN:
  /* Insercion de los datos de softrh.RHMITGF10 a la tabla de ge_movimientos */
/*  FOR c in cuh_rec_gth_rhmitgf10 LOOP
    v_nro_secuencia := nvl(v_nro_secuencia, 0) + 1;
  
    IF nvl(v_nro_secuencia, 0) > 999 THEN
      v_nro_secuencia := 1;
      v_hora          := PAG_GEN.FU_OBT_SIG_SEGUNDO(V_HORA);
    END IF;
  
    BEGIN
      insert into ge_movimientos
        (Fecha,
         Hora,
         Cod_Usuario,
         Nro_Secuencia,
         Fec_valor,
         monto,
         nro_cuenta,
         cod_moneda,
         cod_oficina,
         cod_error,
         est_cuenta,
         estado,
         cod_ofi_origen,
         concepto,
         reversado,
         cod_usu_reversion,
         hor_reversion,
         emi_aviso,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_transaccion,
         cod_modulo,
         cod_modalidad,
         nro_documento,
         nro_documento2,
         nro_documento3,
         nro_documento4,
         referencia)
      VALUES
        (c.fecha,
         v_hora,
         c.usuario,
         v_nro_secuencia,
         c.fecha,
         c.monto,
         c.nro_cuenta,
         c.cod_moneda,
         c.cod_oficina,
         c.cod_error,
         c.est_cuenta,
         c.estado,
         c.cod_ofi_origen,
         c.concepto,
         c.reversado,
         c.cod_usu_reversion,
         c.hor_reversion,
         c.emi_aviso,
         c.cod_tra_padre,
         c.cod_mod_padre,
         c.cod_mad_padre,
         c.cod_transaccion,
         c.cod_modulo,
         c.cod_modalidad,
         c.nro_documento,
         c.nro_documento2,
         c.nro_documento3,
         c.nro_docoumento4,
         c.referencia);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'No se ha podido Insertar en la tabla ge_movimientos. ' || sqlerrm);
    END;
  
    BEGIN
      insert into CB_INF_DER_GASTOS
        (fecha,
         cod_oficina,
         Cod_Area,
         cod_modulo,
         cod_modalidad,
         cod_transaccion,
         cod_moneda,
         Importe,
         referencia,
         Fec_Proceso,
         hor_proceso)
      values
        (v_ult_dia_mes_habil,
         c.cod_oficina,
         c.nro_documento,
         c.cod_modulo,
         c.cod_modalidad,
         c.cod_transaccion,
         c.cod_moneda,
         c.monto,
         ltrim(rtrim(c.referencia)),
         c.fecha,
         v_hora);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000, 'No se ha podido Insertar en la tabla cb_inf_der_gastos. ' || sqlerrm);
    END;
  
  END LOOP;
  /* Insercion de los datos de softrh.RHMITGF10 en las tablas de centros de costos*/

  /*for r in cuh_rec_dat_gth loop
    BEGIN
      select distinct 'S'
        into v_exi_can_per_gasto
        from CB_CAN_PER_GASTOS
       where fec_proceso = r.fecha
         and cod_oficina = r.cod_oficina
         and cod_area = r.cod_area;
    EXCEPTION
      WHEN OTHERS THEN
        v_exi_usuario := 'N';
    END;
  
    IF NVL(v_exi_can_per_gasto, 'N') = 'N' THEN
      BEGIN
        insert into CB_CAN_PER_GASTOS
          (FECHA,
           COD_OFICINA,
           COD_AREA,
           CANTIDAD,
           FEC_PROCESO,
           HOR_PROCESO)
        VALUES
          (v_ult_dia_mes_habil,
           r.cod_oficina,
           r.cod_area,
           r.cant_personas,
           r.fecha,
           v_hora);
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20000, 'No se ha podido Insertar en la tabla cb_can_per_gastos. ' || sqlerrm);
      END;
    END IF;
  end loop;

  commit;*/
  null;
end PRH_INS_GTH_MOVIMIENTOS;
/

