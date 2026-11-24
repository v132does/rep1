create or replace procedure it.prp_ins_sol_prestamos(p_json_data in clob,
                                                     p_solicitud in out pr_solicitudes.nro_solicitud%type,
                                                     p_cod_error out number,
                                                     p_msj_error out varchar2) as
  v_lugar            varchar2(250);
  v_msj_error        varchar2(4000) := 'PROCESO CONCLUIDO CON EXITO';
  v_nro_solicitud    number(10);
  v_nro_linea        pr_lineas.nro_linea%type;
  v_ori_fondo        number := 1;
  v_exo_impuestos    varchar2(1) := 'N';
  v_per_capital      pr_solicitudes.per_vto_capital%type := 30;
  v_mon_local        varchar2(3) := json_value(p_json_data,
                                               '$.currencyCode');
  v_tip_documento    number(1) := 1;
  v_tip_monto        varchar2(1) := 'N';
  v_tip_amortizacion varchar2(1) := 'P';
  v_tip_destino      varchar2(1);
  v_cod_error        number(3) := '000';
  v_cod_sec_credito  number(3) := 701;
  v_cod_oficina      number(3) := fug_obt_ofi_usuario(user);
  v_cod_banca        number;
  v_cod_departamento number(3);
  v_cod_dep_parametro    number(3) := 18; -- Departamento de Parámetros
  v_cod_modulo       number(3) := 6; -- default modulo prestamos
  v_cod_modalidad    ge_modalidades.cod_modalidad%type := json_value(p_json_data,
                                                                     '$.modality');
  v_cod_persona      ba_personas.cod_persona%type := json_value(p_json_data,
                                                                '$.personCode');

  v_cod_sub_modalidad    ge_modalidades.cod_modalidad%type;
  v_descripcion          varchar2(500) := fug_obt_des_modalidad(v_cod_modalidad); -- descripción
  v_cod_usu_promotor     varchar2(10);
  v_cod_usu_oficial      varchar2(10);
  --v_cod_pla_pre_aprobado pr_pre_aprobados.cod_pla_pre_aprobado%type;
  v_cod_rub_economico    pr_solicitudes.cod_rub_economico%type;
  v_cod_garantia         pr_gar_tipos.cod_garantia%type;
  v_cod_campana          number := fug_obt_pardinamico('PRE_DIG_COD_CAMPANA',
                                                       v_cod_modulo,
                                                       v_cod_modalidad);
  v_fec_actual           date := pag_cal.fu_obt_fec_actual(v_cod_modulo);
  v_fec_inicio           date := v_fec_actual;
  v_fec_vto_habil        date;
  v_dia_plazo            number(8) := add_months(to_date(json_value(p_json_data,
                                                                    '$.firstExpirationDate'),
                                                         'YYYY-MM-DD'),
                                                 json_value(p_json_data,
                                                            '$.installmentsQuantity') - 1) -
                                      v_fec_inicio;

  v_fec_pri_vencimiento date := nvl(to_date(json_value(p_json_data,
                                                       '$.firstExpirationDate'),
                                            'YYYY-MM-DD'),
                                    add_months(v_fec_inicio, 1));

  v_fec_vencimiento date := add_months(v_fec_pri_vencimiento,
                                       json_value(p_json_data,
                                                  '$.installmentsQuantity') - 1);
  v_per_gracia      number(8) := v_fec_pri_vencimiento - v_fec_inicio;
  v_cantidad        number(3) := 1;
  v_per_vencimiento number(4) := 30;
  v_val_tasa        number;
  v_val_jso_tasa    pr_sol_tasas.val_tasa%type := to_number(json_value(p_json_data,
                                                                       '$.interestRate'),
                                                            '99G999D99',
                                                            'NLS_NUMERIC_CHARACTERS = ''.,'''); -- tasa json

  v_val_pro_tasa pr_sol_tasas.val_tasa%type := to_number(json_value(p_json_data,
                                                                    '$.promoRate'),
                                                         '99G999D99',
                                                         'NLS_NUMERIC_CHARACTERS = ''.,'''); -- tasa preferencial
  v_clave        number := 1234;
  v_mto_cargo    number(18, 2) := 0;

 function fu_obt_cod_submodalidad(p_cod_modulo       in ge_modalidades.cod_modulo%type,
                                   p_cod_modalidad    in ge_modalidades.cod_modalidad%type,
                                   p_cod_submodalidad in ge_sub_modalidades.cod_sub_modalidad%type)
    return varchar2 is
    v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
  
  begin
    select cod_sub_modalidad
      into v_cod_sub_modalidad
      from ge_sub_modalidades
     where cod_modulo = p_cod_modulo
       and cod_sub_modalidad = p_cod_submodalidad
       and cod_modalidad = p_cod_modalidad;
    return v_cod_sub_modalidad;
  exception
    when too_many_rows then
      select min(cod_sub_modalidad)
        into v_cod_sub_modalidad
        from ge_sub_modalidades
       where cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad;
      return v_cod_sub_modalidad;
    when no_data_found then
      return 1;
    when others then
      return 1;
  end;
procedure pr_obt_rub_y_sec_credito_per(p_cod_persona       in  ba_personas.cod_persona%type,
                                         p_cod_rub_economico out pr_rub_economicos.cod_rub_economico%type,
                                         p_cod_sec_credito   out pr_rub_economicos.referencia%type) is
    v_rub_prim ba_personas.cod_rub_primario%type;
    v_existe   number;
  begin
    p_cod_rub_economico := null;
    p_cod_sec_credito   := null;

    begin
      select p.cod_rub_primario
        into v_rub_prim
        from ba_personas p
       where p.cod_persona = p_cod_persona;

      if v_rub_prim is not null then
        select count(1)
          into v_existe
          from pr_rub_economicos r
         where r.cod_rub_economico = v_rub_prim;

        if v_existe = 1 then
          p_cod_rub_economico := v_rub_prim;
        else
          p_cod_rub_economico := '749911';
        end if;
      else
        p_cod_rub_economico := '749911';
      end if;
    exception
      when no_data_found then
        p_cod_rub_economico := '749900';
    end;

    begin
      select r.referencia
        into p_cod_sec_credito
        from pr_rub_economicos r
       where r.cod_rub_economico = p_cod_rub_economico;
    exception
      when no_data_found then
        p_cod_sec_credito := null;
    end;

    p_cod_sec_credito := nvl(p_cod_sec_credito, 701);
  end;
begin
  -- obtenemos el número de la solicitud 
  select s_nro_sol_prestamos.nextval into v_nro_solicitud from dual;

  -- asignamos sub modalidad 
  v_cod_sub_modalidad := fu_obt_cod_submodalidad(v_cod_modulo,
                                                 v_cod_modalidad,
                                                 1); -- falta definir, debe resolver el json
  -- obtenemos rubro
  -- si no tiene asignado en la oferta, setea default
   -- si no tiene asignado en la oferta, setea default
   IF v_cod_modalidad IN (992, 994) THEN
      pr_obt_rub_y_sec_credito_per(v_cod_persona,
                                   v_cod_rub_economico,
                                   v_cod_sec_credito);
      v_tip_destino := '5';
    ELSE
     ---------- Obtengo el Rubro de la tabla de pre-aprobados------------------
      BEGIN
        SELECT cod_rub_economico
          INTO v_cod_rub_economico
          FROM (
            SELECT pa.cod_rub_economico
              FROM pr_pre_aprobados pa
             WHERE pa.cod_persona = v_cod_persona
               AND pa.estado IN ('G', 'C')
             ORDER BY pa.fec_ini_oferta DESC
          )
         WHERE ROWNUM = 1;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_cod_rub_economico := NULL;
      END;
    END IF;

  -- obtenemos ofi
  begin
    select exo_impuestos,
           cod_usu_oficial,
           cod_usu_promotor,
           cod_oficina,
           cod_departamento
      into v_exo_impuestos,
           v_cod_usu_oficial,
           v_cod_usu_promotor,
           v_cod_oficina,
           v_cod_departamento
      from ba_personas b, ge_clientes g
     where b.cod_persona = g.cod_persona
       and g.cod_persona = v_cod_persona;
  exception
    when no_data_found then
      begin
        select gen.cod_ofi_matriz, 'N', ciu.cod_departamento
          into v_cod_oficina, v_exo_impuestos, v_cod_departamento
          from ge_par_generales gen, ba_oficinas ofi, ba_ciudades ciu
         where gen.cod_ofi_matriz = ofi.cod_oficina
           and ofi.cod_ciudad = ciu.cod_ciudad
           and ofi.cod_pais = ciu.cod_pais;
      end;
  end;

  -- obtenemos el tipo destino en caso de ser nulo 
  if v_tip_destino is null then
    v_tip_destino := fup_obt_tip_destino(v_cod_persona,
                                         v_cod_modalidad,
                                         v_mon_local, --p_cod_moneda,
                                         json_value(p_json_data,
                                                    '$.totalAmount') -
                                         json_value(p_json_data,
                                                    '$.totalInterest'), --v_tot_prestamo - v_mto_interes,
                                         null,
                                         json_value(p_json_data, '$.capital'), --p_mto_solicitado,
                                         json_value(p_json_data,
                                                    '$.installmentsQuantity'));
  end if;

  -- obtenemos la tasa del producto
  begin
    select a.tas_interes
      into v_val_tasa
      from cr_piz_montos b, cr_piz_plazos a
     where a.cod_modulo = v_cod_modulo
       and a.cod_modalidad = nvl(v_cod_modalidad, 602)
       and a.cod_moneda = v_mon_local
       and b.cod_modulo = a.cod_modulo
       and b.cod_modalidad = a.cod_modalidad
       and a.cod_sub_modalidad = b.cod_sub_modalidad
       and b.cod_sub_modalidad = v_cod_sub_modalidad
       and b.cod_moneda = a.cod_moneda
       and b.mto_desde = a.mto_desde
       and json_value(p_json_data, '$.capital') between b.mto_desde and
           b.mto_hasta
       and v_dia_plazo between a.plz_desde and a.plz_hasta;
  exception
    when others then
      v_val_tasa := 20;
  end;
  --1 inserta la solicitud
  if v_cod_error = '000' then
    begin
      insert into pr_solicitudes
        (nro_solicitud,
         descripcion,
         monto,
         tip_amortizacion,
         dia_plazo,
         fec_vencimiento,
         mto_interes,
         per_vto_capital,
         per_gracia,
         cod_persona,
         fec_inicio,
         tip_monto,
         tot_prestamo,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         cod_oficina,
         fec_pri_vencimiento,
         cod_sec_credito,
         cod_departamento,
         tip_documento,
         exo_impuesto,
         cod_usu_promotor,
         cod_canal,
         cod_campana,
         tip_destino,
         cod_banca,
         tip_renovacion,
         cod_ori_fondo,
         por_ori_fondo,
         cod_rub_economico,
         estado,
         est_verificacion,
         nro_linea)
      values
        (v_nro_solicitud,
         nvl(v_descripcion, 'PROMO PRE-APROBADO.'),
         json_value(p_json_data, '$.capital'),
         v_tip_amortizacion,
         v_dia_plazo,
         v_fec_vencimiento,
         json_value(p_json_data, '$.totalInterest'), --v_mto_interes,
         v_per_capital,
         v_per_gracia,
         v_cod_persona,
         v_fec_inicio,
         v_tip_monto,
         json_value(p_json_data, '$.totalAmount') -
         json_value(p_json_data, '$.totalInterest'), --v_tot_prestamo,
         v_cod_modulo,
         v_cod_modalidad,
         v_mon_local,
         v_cod_oficina,
         v_fec_pri_vencimiento,
         v_cod_sec_credito,
         nvl(v_cod_departamento, v_cod_dep_parametro),
         v_tip_documento,
         v_exo_impuestos,
         v_cod_usu_promotor,
         null,
         v_cod_campana,
         v_tip_destino,
         v_cod_banca,
         'A',
         v_ori_fondo,
         100,
         NVL(v_cod_rub_economico, 970108),
         'L',
         decode(v_cod_modalidad, 660, 'N', 'S'),
         v_nro_linea);
    
    exception
      when others then
        v_cod_error := '001';
        v_lugar     := 'Inserta Propuesta';
        v_msj_error := 'Error al insertar la propuesta. ' || sqlerrm;
    end;
  end if;
  --2 Inserta la cuota 0
  if v_cod_error = '000' then
    begin
      insert into pr_sol_cuotas
        (nro_solicitud,
         nro_cuota,
         fec_vto_exacto,
         fec_vto_habil,
         val_interes,
         val_int_adelantado,
         mto_capital,
         sal_capital,
         dia_transcurridos,
         dia_interes,
         dia_periodo)
      values
        (v_nro_solicitud,
         0,
         v_fec_inicio,
         v_fec_inicio,
         0,
         0,
         0,
         json_value(p_json_data, '$.totalAmount') -
         json_value(p_json_data, '$.totalInterest'), --v_tot_prestamo,
         0,
         0,
         0);
    exception
      when others then
        v_cod_error := '002';
        v_lugar     := 'Inserta cuota 0. ';
        v_msj_error := 'Error al insertar cuotas ' || sqlerrm;
    end;
  end if;
  --3 inserta las cuotas 
  -- usamos json_table para aplanar el array de 'installments'
  if v_cod_error = '000' then
    begin
      insert into pr_sol_cuotas cc
        (cc.nro_solicitud,
         cc.nro_cuota,
         cc.fec_vto_habil,
         cc.mto_capital,
         cc.fec_vto_exacto,
         cc.val_interes,
         cc.sal_capital,
         cc.sal_cap_anterior,
         cc.tip_calculo,
         cc.dia_periodo,
         cc.dia_transcurridos,
         cc.dia_interes)
        select v_nro_solicitud,
               jt.installmentNumber,
               to_date(jt.duedate, 'yyyy-mm-dd'),
               jt.principal,
               to_date(jt.duedate, 'yyyy-mm-dd'),
               jt.interest,
               jt.remainingPrincipal, -- Simplificado: (R+P)-P = R
               (jt.remainingPrincipal + jt.principal),
               'V',
               -- CÁLCULO DE DÍAS: Fecha actual menos fecha de la fila anterior
               nvl(to_date(jt.duedate, 'yyyy-mm-dd') -
                   lag(to_date(jt.duedate, 'yyyy-mm-dd'))
                   over(order by jt.installmentNumber),
                   0),
               nvl(to_date(jt.duedate, 'yyyy-mm-dd') -
                   lag(to_date(jt.duedate, 'yyyy-mm-dd'))
                   over(order by jt.installmentNumber),
                   0),
               nvl(to_date(jt.duedate, 'yyyy-mm-dd') -
                   lag(to_date(jt.duedate, 'yyyy-mm-dd'))
                   over(order by jt.installmentNumber),
                   0)
          from json_table(p_json_data,
                          '$.installments[*]'
                          columns(installmentNumber number path
                                  '$.installmentNumber',
                                  dueDate varchar2(10) path '$.dueDate',
                                  totalAmount number path '$.totalAmount',
                                  principal number path '$.principal',
                                  interest number path '$.interest',
                                  remainingPrincipal number path
                                  '$.remainingPrincipal')) jt;
    
    exception
      when others then
        v_cod_error := '003';
        v_lugar     := 'inserta cuotas de la solicitud: ' ||
                       v_nro_solicitud;
        v_msj_error := 'error al insertar cuotas ' || sqlerrm;
    end;
  end if;
  --4 inserta los cargos
  -- usamos json_table para aplanar el array de 'charges'
  if v_cod_error = '000' then
    begin
      insert into pr_sol_cargos
        (nro_solicitud,
         cod_transaccion,
         fec_tasa,
         val_tasa,
         monto,
         cod_tasa,
         cod_ent_seguro,
         cod_moneda,
         mto_mon_prestamo)
        select v_nro_solicitud,
               jt.code,
               v_fec_inicio,
               jt.percentage,
               jt.amount,
               tr.cod_tasa,
               cat.cod_ent_seguro,
               v_mon_local,
               amount
          from json_table(p_json_data,
                          '$.charges[*]'
                          columns(code number path '$.code',
                                  percentage number path '$.percentage',
                                  amount number path '$.amount')) jt
         inner join ge_sol_cargos cat
            on jt.code = cat.cod_transaccion
           and cat.cod_modalidad = v_cod_modalidad
        -- unimos con la lógica de tasas
         inner join ge_transacciones tr
            on tr.cod_transaccion = jt.code
         inner join ge_tasas ta
            on tr.cod_tasa = ta.cod_tasa
         where tr.cod_modulo = v_cod_modulo
           and tr.cod_modalidad = v_cod_modalidad
           and tr.tipo = 'D'
           and tr.cod_tasa is not null
           and exists
         (select 0
                  from ge_transacciones_det td
                 where td.cod_modulo = v_cod_modulo
                   and td.cod_modalidad = v_cod_modalidad
                   and td.cod_transaccion = 358
                   and td.cod_mod_hijo = tr.cod_modulo
                   and td.cod_mad_hijo = tr.cod_modalidad
                   and td.cod_tra_hijo = tr.cod_transaccion);
    exception
      when others then
        v_cod_error := '004';
        v_lugar     := 'Inserta Cargos';
        v_msj_error := 'Error al insertar los cargos. ' || sqlerrm;
    end;
  end if;
  --5 inserta el destino
  if v_cod_error = '000' then
    begin
      insert into pr_sol_destinos
        (nro_solicitud, tip_des_especifico, monto)
      values
        (v_nro_solicitud,
         3,
         decode(v_cod_modalidad,
                660,
                round(json_value(p_json_data, '$.capital') / v_cantidad, 2),
                json_value(p_json_data, '$.totalAmount')));
    exception
      when others then
        v_cod_error := '005';
        v_lugar     := 'Inserta PR_SOL_DESTINOS ';
        v_msj_error := 'Error al insertar destinos ' || sqlerrm;
    end;
  end if;
  --6 inserta la garantia
  if v_cod_error = '000' then
    begin
      select cod_garantia
        into v_cod_garantia
        from pr_gar_tipos
       where descripcion like '%SOLA%FIRMA%';
      -- se inserta la garantía
      insert into pr_sol_garantias
        (nro_solicitud, cod_garantia, mto_aplicado)
      values
        (v_nro_solicitud,
         v_cod_garantia,
         decode(v_cod_modalidad,
                660,
                round(json_value(p_json_data, '$.capital') / v_cantidad, 2),
                json_value(p_json_data, '$.totalAmount')));
    exception
      when others then
        v_cod_error := '006';
        v_lugar     := 'Inserta PR_SOL_GARANTIAS ';
        v_msj_error := 'Error al insertar garantias ' || sqlerrm;
    end;
  end if;
  --7 inserta la tasa
  if v_cod_error = '000' then
    begin
      insert into pr_sol_tasas
        (nro_solicitud, fec_vigencia, val_tasa, tip_cobro, per_vencimiento)
      values
        (v_nro_solicitud,v_fec_inicio,nvl(nvl(v_val_pro_tasa, v_val_jso_tasa), v_val_tasa),'V',v_per_vencimiento);
    exception
      when others then
        v_cod_error := '007';
        v_lugar     := 'Inserta PR_SOL_TASAS ';
        v_msj_error := 'Error al insertar Tasas ' || sqlerrm;
    end;
  end if;
  --8 inserta los datos adicionales
  if v_cod_error = '000' then
    begin
      insert into ba_tab_dat_adicionales
        (tab_relacion, referencia, parametro, val_parametro)
      values
        ('PR_SOLICITUDES', v_nro_solicitud, 'CLA_PRE_APROBADO', v_clave);
    
    exception
      when others then
        v_cod_error := '008';
        v_lugar     := 'Inserta Datos Adicionales ' || v_nro_solicitud;
        v_msj_error := 'Error al insertar datos adicionales ' || sqlerrm;
    end;
  end if;
  --9 actualiza el total de cargos de la solicitud
  begin
    select nvl(sum(a.monto), 0)
      into v_mto_cargo
      from pr_sol_cargos a
     where a.nro_solicitud = v_nro_solicitud;
  exception
    when others then
      v_mto_cargo := 0;
  end;

  update pr_solicitudes
     set mto_cargo = v_mto_cargo
   where nro_solicitud = v_nro_solicitud;

  --10 actualiza el dia_periodo de la cuota 1
  begin
    select fec_vto_habil
      into v_fec_vto_habil
      from pr_sol_cuotas aa
     where aa.nro_solicitud = v_nro_solicitud
       and nro_cuota = 1;
  exception
    when others then
      v_fec_vto_habil := null;
  end;

  update pr_sol_cuotas aa
     set dia_periodo       = v_fec_vto_habil - v_fec_inicio,
         dia_transcurridos = v_fec_vto_habil - v_fec_inicio,
         dia_interes       = v_fec_vto_habil - v_fec_inicio
   where aa.nro_solicitud = v_nro_solicitud
     and nro_cuota = 1;

  -- salida
  if v_cod_error = '000' then
    p_solicitud := v_nro_solicitud;
    p_cod_error := v_cod_error;
    p_msj_error := v_msj_error;
    commit;
  else
    p_cod_error := v_cod_error;
    p_msj_error := v_msj_error;
    prg_ins_log_programas('PRP_INS_SOL_PRESTAMOS',
                          ' ERROR: ' || p_cod_error || ' LUGAR: ' ||
                          v_lugar || ' - ' || p_msj_error,
                          v_cod_persona,
                          null);
    p_solicitud := null;
    rollback;
  end if;

exception
  when others then
    rollback;
    dbms_output.put_line('Error al insertar datos: ' || sqlerrm);
    raise;
end prp_ins_sol_prestamos;
/
