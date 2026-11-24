CREATE OR REPLACE TRIGGER IT.TA_SB_TAS_APE_SEMANALES
  after insert
  on sb_tas_ape_semanales
  for each row

declare

  v_valor_cambio       ge_cotizaciones.val_conversion%type;
  v_cod_moneda         mi_sb_tas_ape_semanales.cod_moneda%type;
  v_monto              sb_tas_ape_semanales.monto%type;
  v_mto_ape_original   sb_tas_ape_semanales.mto_ape_original%type;
  v_periodo            number(10);
  v_acod               varchar2(5);
  v_corcod             varchar2(10);
  v_entcod             mi_sb_tas_ape_semanales.entcod%type;
  v_codcta             mi_sb_tas_ape_semanales.codcta%type;
  v_plazo              NUMBER(5);
  v_tasreg             mi_sb_tas_ape_semanales.tasreg%type;
  v_tip_capitalizacion ah_cta_certificados.tip_capitalizacion%type;
  v_error              log_mi_sb_tas_ape_semanales.error%type;

  v_cod_mon_fuerte     ge_par_generales.cod_mon_fuerte%type;
  v_cod_mon_local      ge_par_generales.cod_mon_local%type;
  r_pcpre              pr_cta_prestamos%rowtype;
  v_fec_apertura       ge_cuentas.fec_apertura%type;
  v_val_tasa           pr_cta_prestamos.val_tasa%type;

  v_cod_rubro          cb_sal_inventarios.cod_rubro%type;
  v_tip_saldo          cb_sal_inventarios.tip_saldo%type;
  v_descripcion        ge_est_cuentas.descripcion%type;
begin
  v_cod_mon_fuerte := pag_gen.fu_obt_mon_fuerte;
  v_cod_mon_local  := pag_gen.fu_obt_mon_local;
  v_fec_apertura   := :new.fec_apertura;
  /* MONEDA: Para guaranies 6900, y dolares 6200 */
  IF :NEW.cod_mon_original = v_cod_mon_fuerte THEN
    v_cod_moneda := '6200';
    /* Recuperar Valor de Cambio */
    BEGIN
       v_valor_cambio :=  pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte, TRUNC(:new.fec_apertura));
    EXCEPTION
      WHEN OTHERS THEN
        v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
          (FECHA_PROCESO, ERROR, MENSAJE)
        VALUES
          (SYSDATE, v_error, 'Problemas al recuperar cotizacion');
    END;
    if :new.cod_modalidad = 31 then
      v_monto := (nvl(:new.monto,0) * nvl(v_valor_cambio,0))/1000;
    else
      v_monto := (nvl(:new.monto, 0) * nvl(v_valor_cambio, 0)) / 1000;
    end if;
    v_mto_ape_original := (nvl(:new.mto_ape_original, 0) *
                            nvl(v_valor_cambio, 0)) / 1000;
  ELSIF :NEW.COD_MON_ORIGINAL = v_cod_mon_local THEN
    v_cod_moneda       := '6900';
    if :new.cod_modalidad = 31 then
      v_monto := :new.monto / 1000;
    else
      v_monto := :new.monto / 1000;
    end if;
    v_mto_ape_original := :new.mto_ape_original / 1000;
  END IF;
  /* CORCOD: Fecha de corte semanal, se ingresa como parametro.
  Estas fechas de corte son proveidas por el BCP */
  BEGIN
     SELECT SEMANA
       INTO v_corcod
       FROM SB_SEMANAS
      WHERE :NEW.FEC_APERTURA BETWEEN DESDE AND HASTA;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
                 SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
      INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
        (FECHA_PROCESO, ERROR, MENSAJE)
      VALUES
        (SYSDATE, v_error, 'La fecha ingresada no es valida');
    WHEN OTHERS THEN
      v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
                 SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
      INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
        (FECHA_PROCESO, ERROR, MENSAJE)
      VALUES
        (SYSDATE, v_error, 'Problemas al determinar semana');
  END;
  /* ENTCOD: Es el codigo de entidad (codigo BCP) */
  v_entcod := pag_gen.fu_obt_cod_entidad;
  /* CODCTA: Es el tipo de operacion cartera relacionada con contabilidad,
  solo 156000, en este caso (CDA) */
  if :new.cod_modalidad = 31 then
    v_codcta := '138000';
  elsif :new.cod_modalidad = 33 then
    v_codcta := '156000';
  elsif :new.cod_modalidad = 34 then
    v_codcta := '214000';
  elsif :new.cod_modulo = 5 then
    v_codcta := '205002';
  else
    --- Prestamos o tarjetas
    v_codcta := fug_obt_mod_sup_rubro(:new.cod_modulo,:new.nro_cuenta);
    v_codcta := rpad(substr(v_codcta,1,3),6,'0');
    if nvl(fug_obt_pardinamico('SIB_MAD_COM_CARTERA',:new.cod_modulo,:new.cod_modalidad ),'N') = 'S' THEN
       v_codcta := '433000';  -- compra de cartera
    elsif nvl(fup_obt_tip_descuento(:new.cod_modalidad),'x') in ('F','C') then
       v_codcta := '405001';  -- descuento de cheques
    elsif nvl(fup_obt_tip_descuento(:new.cod_modalidad),'x') = 'D' then
       v_codcta := '351000';  -- descuento de documentos
    end if;
  end if;
  if :new.cod_mon_original = v_cod_mon_local then
    v_cod_moneda       := '6900';
  else
    v_cod_moneda       := '6200';
  end if;

  if :new.cod_modalidad = 31 then
    v_plazo := 0;
    v_tip_capitalizacion := 3; --- Fijo Trimestral, la mayoria
    select decode(v_tip_capitalizacion,
                  1,
                  30,
                  2,
                  60,
                  3,
                  90,
                  4,
                  120,
                  6,
                  180,
                  12,
                  365,
                  99,
                  v_plazo,
                  null)
      into v_periodo
      from dual;
    /* TASREG: Vencida o Adelantada, en este caso solamente Vencida (V) */
    v_tasreg := 'V';
    /* ACOD: Es el area que corresponde, de acuerdo al plazo de la operacion */
    v_acod := 2021;
  elsif :new.cod_modalidad = 33 then
    BEGIN
      SELECT FEC_VENCIMIENTO - FEC_APERTURA
        INTO v_plazo
       FROM ah_cta_certificados
       WHERE nro_cuenta = :NEW.NRO_CUENTA;
    EXCEPTION
      WHEN OTHERS THEN
        v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES (SYSDATE, v_error, 'Problemas al recuperar plazo');
    END;
    IF v_plazo <= 180 THEN
      v_acod := '2075';
    ELSIF v_plazo <= 365 THEN
      v_acod := '2076';
    ELSIF v_plazo > 365 THEN
      v_plazo := 365;
      v_acod := '2077';
    END IF;
    /* PERIODO: Depende del tipo de capitalizacion (TIP_CAPITALIZACION)
    de la tabla ah_cta_certificados */
    BEGIN
      SELECT TIP_CAPITALIZACION
        INTO v_tip_capitalizacion
        FROM AH_CTA_CERTIFICADOS
       WHERE NRO_CUENTA = :NEW.NRO_CUENTA;
    EXCEPTION
      WHEN OTHERS THEN
        v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES (FECHA_PROCESO, ERROR, MENSAJE)
          VALUES (SYSDATE, v_error, 'Problemas al recuperar Tipo de Capitalizacion');
    END;
    select decode(v_tip_capitalizacion,
                  1,
                  30,
                  2,
                  60,
                  3,
                  90,
                  4,
                  120,
                  6,
                  180,
                  12,
                  365,
                  99,
                  v_plazo,
                  null)
      into v_periodo
      from dual;
    /* TASREG: Vencida o Adelantada, en este caso solamente Vencida (V) */
    v_tasreg := 'V';
  end if;
  --- Prestamos
  if :new.cod_modulo = 6 then
     pap_pre.pr_obt_dat_prestamo(:new.nro_cuenta,r_pcpre);
     v_plazo   := r_pcpre.fec_vencimiento - r_pcpre.fec_inicio;
     v_tasreg  := r_pcpre.tip_interes;
       BEGIN
      select p.cod_rubro, p.tip_saldo, trim(d.descripcion)
        into v_cod_rubro, v_tip_saldo, v_descripcion
        from cb_sal_inventarios     p,
             cb_sal_inventarios_det b,
             pr_cta_prestamos       c,
             ge_est_cuentas         d
       where p.nro_referencia = b.nro_referencia
         and b.nro_cuenta = :new.nro_cuenta
         and c.nro_cuenta = b.nro_cuenta
         and d.cod_modulo = c.cod_modulo
         and d.cod_modalidad = c.cod_modalidad
         and c.estado = d.estado
         and p.tip_saldo = 'C';
    
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- JFF busca en historico sino existe el cod_rubro en el inventario actual
        BEGIN
           select p.cod_rubro, p.tip_saldo, trim(d.descripcion)
             into v_cod_rubro, v_tip_saldo, v_descripcion
        from cb_sal_inventarios_his     p,
             cb_sal_inventarios_det_his b,
             pr_cta_prestamos       c,
             ge_est_cuentas         d
       where p.nro_referencia = b.nro_referencia
         and b.nro_cuenta = :new.nro_cuenta
         and c.nro_cuenta = b.nro_cuenta
         and d.cod_modulo = c.cod_modulo
         and d.cod_modalidad = c.cod_modalidad
         and c.estado = d.estado
         and p.tip_saldo = 'C'
         and b.fecha = p.fecha
         and b.fecha =( select max( g.fecha)  from cb_sal_inventarios_det_his g where g.nro_cuenta=b.nro_cuenta)
         ;
        
        EXCEPTION
              WHEN no_data_found THEN
                     v_error := 'Consulta Cta: ' || :new.nro_cuenta || ' - ' ||
                       SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
            INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
              (FECHA_PROCESO, ERROR, MENSAJE)
            VALUES
              (SYSDATE, v_error, 'Cuenta no existe en el inventario!');
        END;
        
       
    END;

     v_acod    := fus_obt_are_bcp_cta(:new.nro_cuenta,:new.cod_modulo,v_tip_saldo,v_cod_rubro,v_descripcion);
     --- informar el promedio si la cuenta es de modalidad descuento en periodo
     If fup_obt_tip_descuento(r_pcpre.cod_modalidad) in ('D','C','F') then
        select avg(fec_vencimiento - r_pcpre.fec_inicio)
          into v_periodo
          from pr_cuotas
         where nro_cuenta = :new.nro_cuenta
           and nro_cuota > 0;
     else
       v_periodo := r_pcpre.per_vto_capital;
       If r_pcpre.can_cuotas = 1 then
         v_periodo := r_pcpre.fec_vencimiento - r_pcpre.fec_inicio;
       End if;
     End if;
     if v_periodo > 365 then
        --- Agregado el 23/06/08 pedido: Juan Silvero de BCP dijo que el sistema de tasas no acepta periodo > 365
        v_periodo := 365;
     end if;
  end if;
  --- Tarjetas
  if :new.cod_modulo = 5 then
     v_plazo   := 0;
     v_tasreg  := 'V';
     v_acod    := fus_obt_are_bcp_cta(:new.nro_cuenta,:new.cod_modulo);
     v_periodo := 30;
  end if;
  --- Verificar el monto
  if v_monto < 1 then
     v_monto := 1;
  end if;
  IF INSERTING THEN
    /*if :new.cod_modulo = 6 then
      select val_tasa
        into v_val_tasa
        from pr_cta_prestamos
       where nro_cuenta = :new.nro_cuenta;
    end if;*/
    BEGIN
      INSERT INTO MI_SB_TAS_APE_SEMANALES
        (NRO_CUENTA,
         COD_MODULO,
         COD_MODALIDAD,
         COD_MON_ORIGINAL,
         COD_MONEDA,
         FEC_APERTURA,
         MTO_APE_ORIGINAL,
         MONTO,
         VAL_TAS_NOMINAL,
         VAL_TAS_EFECTIVA,
         COD_PLAZO,
         CORCOD,
         ENTCOD,
         CODCTA,
         ACOD,
         PERIODO,
         TASREG,
         USU_INSERCION,
         FEC_INSERCION,
         USU_MODIFICACION,
         FEC_MODIFICACION)
      VALUES

        (:NEW.NRO_CUENTA,
         :NEW.COD_MODULO,
         :NEW.COD_MODALIDAD,
         :NEW.COD_MON_ORIGINAL,
         v_cod_moneda,
         v_fec_apertura,
         v_mto_ape_original,
         v_monto,
         --decode(:new.cod_modulo,6,v_val_tasa,:NEW.VAL_TAS_NOMINAL),
         :NEW.VAL_TAS_NOMINAL,
         :NEW.VAL_TAS_EFECTIVA,
         :NEW.COD_PLAZO,
         v_corcod,
         v_entcod,
         v_codcta,
         v_acod,
         v_periodo,
         v_tasreg,
         :NEW.USU_INSERCION,
         :NEW.FEC_INSERCION,
         :NEW.USU_MODIFICACION,
         :NEW.FEC_MODIFICACION);
    EXCEPTION
      WHEN OTHERS THEN

        v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
                   SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
        INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
          (FECHA_PROCESO, ERROR, MENSAJE)
        VALUES
          (SYSDATE,
           v_error,
           'Problemas al insertar datos en tabla destino');

    END;

  END IF;

exception
  when others then
    v_error := 'Cuenta: ' || :new.nro_cuenta || ' - ' ||
               SUBSTR(TO_CHAR(SQLERRM), 1, 1000);
    INSERT INTO LOG_MI_SB_TAS_APE_SEMANALES
      (FECHA_PROCESO, ERROR, MENSAJE)
    VALUES
      (SYSDATE, v_error, 'ERROR EN EJECUCION DE TRIGGER - ');

end MA_SB_TAS_APE_SEMANALES;
/

