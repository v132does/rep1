CREATE OR REPLACE PROCEDURE IT.PRG_OBT_MSJ_MT940_V1(p_fec_desde      in date,
                                                    p_fec_hasta      in date,
                                                    p_nro_cuenta     in varchar2,
                                                    p_tip_generacion in varchar2 default 'D',
                                                    p_periodicidad   in varchar2 default 'D',
                                                    p_swift_destino  in varchar2,
                                                    p_cod_error      out varchar2,
                                                    p_mensaje        out varchar2)
 IS

  v_texto                clob;
  v_fec_actual           varchar2(6);
  v_fec_final            varchar2(6);
  v_fec_anterior         date := to_date(to_char(it.PAG_CAL.FU_OBT_FEC_ANT_HAB(p_fec_desde, 61, 1),'DD/MM/YYYY'),'DD/MM/YYYY');
  v_fec_ant_chr          varchar2(6) := to_char(p_fec_desde, 'yymmdd');
  v_mascara              varchar2(15);
  v_detalle              varchar2(1);
  v_cod_moneda           varchar2(3);
  v_tip_saldo            varchar2(1); -- Tipo Débito/Crédito
  v_tip_sal_int          varchar2(1); -- Tipo Débito/Crédito
  v_duplicado            varchar2(1) := 'N';
  v_cnt_mensaje          number;
  v_cnt_lineas           number := 0;
  v_secuencia            number := 0;
  v_cod_swift            varchar2(20);
  v_salto                varchar2(2) := CHR(13) || CHR(10);
  v_fecha                date;
  v_cod_swi_corresponsal varchar2(12);
  v_tipo                 ge_transacciones.tipo%type; -- Tipo de Movimiento de la Transacción, Débito/Crédito
  v_sal_inicial          ge_sal_diarios.sal_tot_cap%type;
  v_sal_final            ge_sal_diarios.sal_tot_cap%type;
  v_mto_intermedio       ge_sal_diarios.sal_tot_cap%type;
  v_mto_movimiento       ge_sal_diarios.sal_tot_cap%type;
  v_nro_sec_cta          number;
  v_ind_sec_cta          varchar2(1);
  v_log_mensaje          varchar2(4000);
  v_modulo               ge_cuentas.cod_modulo%type;
  v_modalidad            ge_cuentas.cod_modalidad%type;
  v_desc_modal           ge_modalidades.descripcion%type;
  v_des_mov              varchar2(25);
  v_ext_id               ge_dat_transferencias.ext_id%type;
  v_nro_transaccion      varchar2(50);

  cursor c_cta is
    select c.nro_cuenta,
           c.cod_banco,
           c.cod_moneda,
           cc.cod_persona,
           nvl(c.sal_tot_batch, 0) sal_tot_batch,
           nvl(c.sal_total, 0) sal_total,
           nvl(c.sal_total, 0) - nvl(c.sal_bloqueado, 0) - nvl(c.sal_retenido, 0) sal_disponible
      from cc_cta_corrientes c, ge_cta_clientes cc, ge_est_cuentas e
     where c.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and c.cod_modulo = e.cod_modulo
       and c.cod_modalidad = e.cod_modalidad
       and c.estado = e.estado
       and e.activo = 'S'
       and c.nro_cuenta = nvl(p_nro_cuenta, c.nro_cuenta)
       and not exists (select 1
              from ge_cta_dat_adicionales da
             where c.nro_cuenta = da.nro_cuenta
               and da.parametro = 'MSJ_MT940_NEW'
               and nvl(da.val_parametro, 'N') = 'S')
    union all
    select v.nro_cuenta,
           v.cod_banco,
           v.cod_moneda,
           cc.cod_persona,
           nvl(v.sal_tot_batch, 0) sal_tot_batch,
           nvl(v.sal_total, 0) sal_total,
           nvl(v.sal_total, 0) - nvl(v.sal_bloqueado, 0) - nvl(v.sal_retenido, 0) sal_disponible
      from ah_cta_vistas v, ge_cta_clientes cc, ge_est_cuentas e
     where v.nro_cuenta = cc.nro_cuenta
       and cc.relacion = 'P'
       and v.cod_modulo = e.cod_modulo
       and v.cod_modalidad = e.cod_modalidad
       and v.estado = e.estado
       and e.activo = 'S'
       and v.nro_cuenta = nvl(p_nro_cuenta, v.nro_cuenta)
       and not exists (select 1
              from ge_cta_dat_adicionales da
             where v.nro_cuenta = da.nro_cuenta
               and da.parametro = 'MSJ_MT940_NEW'
               and nvl(da.val_parametro, 'N') = 'S')
     order by 1;
  --
  c c_cta%rowtype;
  --
  cursor c_mov(p_cuenta varchar2) is
    select p.cod_servicio, regexp_substr(p.par_enviados, '\d+',5) nro_transaccion, m.*
      from gv_movimientos m, ge_transacciones t, bw_pag_servicios p
     where m.cod_modulo = t.cod_modulo
       and m.cod_modalidad = t.cod_modalidad
       and m.cod_transaccion = t.cod_transaccion
       and m.fecha between p_fec_desde and p_fec_hasta
       and m.nro_cuenta = p_cuenta
          -- Para tomar reversiones
       and (m.reversado = 'N' or (m.reversado = 'S' and m.fec_valor < m.fecha and m.fec_valor <= p_fec_hasta and m.monto < 0))
       and nvl(m.monto, 0) <> 0
       and upper(m.tip_movimiento) in ('DEBITO', 'CREDITO')
       and m.tipo = 'H'
       and t.ve_cliente = 'S'
       and nvl(t.afecta,'XX') != 'B'
       and m.NRO_CUENTA = p.nro_cuenta(+)
       and m.HORA = p.hora(+)
       and m.NRO_DOCUMENTO2 = p.cod_servicio(+)
       and m.nro_documento = p.nro_transaccion(+)
       and m.COD_MONEDA = p.cod_moneda(+)
       and m.MONTO = p.mto_transaccion(+)
    order by m.fec_insercion, m.hora, m.nro_secuencia;
    --
  cursor c_mov_r(p_cuenta varchar2) is
    select cod_tip_movimiento,
           0 nro_documento,
           0 nro_documento4,
           sum(monto) monto,
           upper(des_transaccion) des_transaccion,
           t.cod_transaccion,
           m.fecha
      from gv_movimientos m, ge_transacciones t
     where m.cod_modulo = t.cod_modulo
       and m.cod_modalidad = t.cod_modalidad
       and m.cod_transaccion = t.cod_transaccion
       and m.fecha between p_fec_desde and p_fec_hasta
       and m.nro_cuenta = p_cuenta
          --- Para tomar reversiones
       and (m.reversado = 'N' or (m.reversado = 'S' and m.fec_valor < m.fecha and m.fec_valor <= p_fec_hasta and m.monto < 0))
       and nvl(m.monto, 0) <> 0
       and upper(m.tip_movimiento) in ('DEBITO', 'CREDITO')
       and m.tipo = 'H'
       and t.ve_cliente = 'S'
       and nvl(t.afecta,'XX') != 'B'
     group by cod_tip_movimiento, upper(des_transaccion), t.cod_transaccion, m.fecha
     order by cod_tip_movimiento, upper(des_transaccion), t.cod_transaccion, m.fecha;
  --
  procedure lp_cab_mensaje is
  begin
    -- ********************Obtener y Actualizar el statemen number (Nro. de Extracto)******************
    if nvl(v_cnt_mensaje, 1) = 1 then
      -- DYDMR-4562 -OMM-27/07/2016- Se agrega para no cambiar la secuencia por cantidad de msj
      v_nro_sec_cta := fug_obt_paradicional(c.nro_cuenta, 'NRO_SEC_CTA_MT940');
      if v_nro_sec_cta is null then
        v_nro_sec_cta := 363;
        v_ind_sec_cta := 'N';
      else
        v_ind_sec_cta := 'S';
      end if;
      v_nro_sec_cta := v_nro_sec_cta + 1;
      if v_ind_sec_cta = 'S' then
        -- Actualiza la secuencia del Nro de Cuenta
        begin
          update ge_cta_dat_adicionales a
             set a.val_parametro = trim(to_char(v_nro_sec_cta))
           where a.parametro = 'NRO_SEC_CTA_MT940'
             and a.nro_cuenta = c.nro_cuenta;
          IF SQL%NOTFOUND THEN
            v_log_mensaje := 'Datos Adicionales no encontrado (Diario): ' || sqlerrm;
            p_mensaje     := 'Datos Adicionales no encontrado (Diario) ';
            p_cod_error   := 4;
            prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
          END IF;
        exception
          when others then
            v_log_mensaje := 'Error en Actualizacion de Datos Adicionales (Diario): ' || sqlerrm;
            p_mensaje     := 'Error en Actualizacion de Datos Adicionales (Diario): ';
            p_cod_error   := 5;
            prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
        end;
      end if;
    end if;
    -- ********************************** cabecera ****************************************************
    -- 1: Dirección de Origen
    v_texto := null;
    v_texto := v_texto || '{1:F01' || upper(v_cod_swift) || 'XXX0000000000}';
    -- 2: Dirección de Destino
    --Codigo BIC de 8 **Nuevo bloque IF
    if length(v_cod_swi_corresponsal) = 8 then
      v_texto := v_texto || '{2:I940' || upper(v_cod_swi_corresponsal) || 'XXXXN' || '}';
    else
      --Codigo BIC de 11
      v_texto := v_texto || '{2:I940' || upper(substr(v_cod_swi_corresponsal, 1, 8)) || 'X' ||
                 upper(substr(v_cod_swi_corresponsal, -3)) || 'N' || '}';
    end if;

    v_texto := v_texto || '{4:' || v_salto;
    -- ****************************** cuerpo del mensaje **********************************************
    -- 20: Numero de referencia - Identificación del Cliente y Fecha
    v_texto := v_texto || ':20:C' || to_char(sysdate, 'yyyymmddhh24miss') || v_salto;
    -- 25: Nro. de Cuenta Informada
    v_texto := v_texto || ':25:' || c.nro_cuenta || v_salto;
    -- 28C: Nro. de Mensaje/Nro. de Secuencia
    select v_texto || ':28C:' ||to_char(sysdate, 'YY')||LPAD(to_char(v_nro_sec_cta), 3, '0') || '/' || v_cnt_mensaje || v_salto into v_texto from dual;
    -- Tipo de Saldo Crédito o Débito
    if v_sal_inicial < 0 then
      v_tip_saldo := 'D';
    else
      v_tip_saldo := 'C';
    end if;
    -- 60F: Saldo día Anterior
    if nvl(v_cnt_mensaje, 1) = 1 then
      v_texto := v_texto || ':60F:' || v_tip_saldo || v_fec_ant_chr || v_cod_moneda ||
                 replace(ltrim(rtrim(to_char(abs(v_sal_inicial), v_mascara))), '.', ',') || v_salto;
    else
      -- OMM Ene/2018 se agrega el saldo intermedio cuando hay más de una pagina
      -- Tipo de Saldo Crédito o Débito
      if v_mto_intermedio < 0 then
        v_tip_sal_int := 'D';
      else
        v_tip_sal_int := 'C';
      end if;
      DBMS_LOB.APPEND(v_texto, ':60M:' || v_tip_sal_int || v_fec_actual || v_cod_moneda ||
                      replace(ltrim(rtrim(to_char(abs(v_mto_intermedio), v_mascara))), '.', ',') || v_salto);
    end if;

    if nvl(v_detalle, 'N') = 'N' then
      if c.sal_disponible < 0 then
        v_tip_saldo := 'D';
      else
        v_tip_saldo := 'C';
      end if;
      -- 62F: Saldo Actual
      DBMS_LOB.APPEND(v_texto, ':62F:' || v_tip_saldo || v_fec_final || v_cod_moneda ||
                      replace(ltrim(rtrim(to_char(abs(v_sal_final), v_mascara))), '.', ',') || v_salto);
      DBMS_LOB.APPEND(v_texto, '-}');
    else
      v_cnt_lineas := 5;
    end if;
  end;

  procedure lp_ini_sec_anual is
  begin
    if to_char(v_fecha, 'yyyy') <> to_char(v_fec_anterior, 'yyyy') then
      --Se debe reiniciar a 0 los parametros, cambio el año--
      update ge_cta_dat_adicionales
         set val_parametro = '0'
       where parametro = 'NRO_SEC_CTA_MT940';
      IF SQL%NOTFOUND THEN
        v_log_mensaje := 'Datos Adicionales no encontrado (Anual): ' || sqlerrm;
        p_mensaje     := 'Datos Adicionales no encontrado (Anual): ';
        p_cod_error   := 6;
        prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
      END IF;
    end if;
  exception
    when others then
      v_log_mensaje := 'Error en Actualizacion de Datos Adicionales (Anual): ' || sqlerrm;
      p_mensaje     := 'Error en Actualizacion de Datos Adicionales (Anual): ';
      p_cod_error   := 7;
      prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
  end;

  Procedure pr_ins_ge_men_cli_mt940 is
  Begin
    insert into it.ge_men_cli_mt940_v1
      (cod_persona,
       nro_cuenta,
       fec_extracto,
       nro_extracto,
       nro_secuencia,
       extracto,
       estado,
       tip_generacion,
       periodicidad,
       fec_desde,
       fec_hasta,
       cod_swift_dest)
    values
      (c.cod_persona,
       c.nro_cuenta,
       v_fecha,
       v_nro_sec_cta,
       v_cnt_mensaje,
       v_texto,
       'G',
       p_tip_generacion,
       p_periodicidad,
       p_fec_desde,
       p_fec_hasta,
       p_swift_destino);

  exception
    when others then
      v_log_mensaje := 'Error al insertar en ge_men_cli_mt940: ' || sqlerrm;
      p_mensaje     := 'Error al insertar en ge_men_cli_mt940 ';
      p_cod_error   := 8;
      prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
  end;

BEGIN

  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;

  v_fec_actual := to_char(pae_cnf.fu_obt_fec_actual(4), 'yymmdd');
  v_fecha      := trunc(pae_cnf.fu_obt_fec_actual(4));
  v_fec_final  := to_char(p_fec_hasta, 'yymmdd');

  --Se busca Modulo Modalidad de la cuenta
    begin
      Select t.cod_modulo, t.cod_modalidad
        into v_modulo, v_modalidad
        from ge_cuentas t
       where t.nro_cuenta = p_nro_cuenta;
    exception
      when others then
        null;
    end;
   -- Se obtiene la descripcion de la modalidad
   v_desc_modal := it.FUG_OBT_DES_MODAL(v_modulo, v_modalidad);

  -- Valida que solo se ejecute una vez por día
  Begin
    Select 'S'
      into v_duplicado
      from it.ge_men_cli_mt940_v1 a
     where a.fec_desde = p_fec_desde
       and a.fec_hasta = p_fec_hasta
       and a.nro_cuenta = p_nro_cuenta
       and a.tip_generacion = p_tip_generacion
       and a.periodicidad = p_periodicidad ;
  exception
    when no_data_found then
      v_duplicado := 'N';
    when others then
      v_duplicado := 'N';
  end;
  -- Control para no generar duplicados
  if v_duplicado = 'S' then
    v_log_mensaje := 'Ya se encuentran registros de la fecha: ' || sqlerrm;
    p_mensaje     := 'Ya se encuentran registros de la fecha ';
    p_cod_error   := 1;
    prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
  end if;

  lp_ini_sec_anual;
  -- obtengo el codigo de swift del banco origen
  --select pas_snp.fu_obt_cod_swi_participante(fug_obt_per_entidad) into v_cod_swift from dual;
   v_cod_swift := fug_obt_pardinamico(p_parametro     => 'COD_SWIFT_ORIGEN_MT940',
                                      p_cod_modulo    => null, p_cod_modalidad => null,
                                      p_cod_moneda    => null, p_cod_oficina   => null);

  -- leo los datos del registro de la operacion
  if c_cta%isopen then
    close c_cta;
  end if;
  open c_cta;
  loop
    fetch c_cta
      into c;
    exit when c_cta%notfound;
    -- Cantidad de Mensajes
    v_cnt_mensaje := 1;
    -- Cantidad de Cuentas
    v_secuencia      := v_secuencia + 1;
    v_mto_movimiento := 0;
    v_mto_intermedio := 0;
    v_texto          := '';
    --
    if c.cod_moneda = 'GS' then
      v_cod_moneda := 'PYG';
      v_mascara    := '999999999990D'; --999999999999
    else
      v_cod_moneda := c.cod_moneda;
      v_mascara    := '999999999990D99';
    end if;
    -- obtengo los datos del banco corresponsal del operante
    begin
       v_cod_swi_corresponsal := p_swift_destino;
    exception
      when others then
        v_cod_swi_corresponsal := null;
    end;
    -- Busca si la cta. tiene movimientos
    begin
      select distinct 'S'
        into v_detalle
        from gv_movimientos m, ge_transacciones t
       where m.cod_modulo = t.cod_modulo
         and m.cod_modalidad = t.cod_modalidad
         and m.cod_transaccion = t.cod_transaccion
         and m.fecha between p_fec_desde and p_fec_hasta
         and m.nro_cuenta = c.nro_cuenta
            --- Para tomar reversiones
         and (m.reversado = 'N' or
             (m.reversado = 'S' and m.fec_valor < m.fecha and m.fec_valor <= p_fec_hasta and m.monto < 0))
         and nvl(m.monto, 0) <> 0
         and upper(m.tip_movimiento) in ('DEBITO', 'CREDITO')
         and m.tipo = 'H'
         and t.ve_cliente = 'S'
         and nvl(t.afecta,'XX') != 'B';
    exception
      when no_data_found then
        v_detalle := 'N';
      when others then
        v_log_mensaje := 'Error en Movimientos: ' || sqlerrm;
        p_mensaje     := 'Error en Movimientos ';
        p_cod_error   := 2;
        prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
    end;
    -- OMM ENE/2018 ESTO SE AGREGARÁ EN LA GENERACIÓN DEL ARCHIVO COMO SEPARADOR
    -- Busca Saldo Inicial de la Cuenta
    begin
      select (s.sal_tot_cap - s.sal_ret_ade) -- s.sal_tot_cap
        into v_sal_inicial
        from ge_sal_diarios s
       where nro_cuenta = c.nro_cuenta
         and fecha = v_fec_anterior;
    exception
      when no_data_found then
        v_sal_inicial := 0;
      when others then
        v_log_mensaje := 'Error al buscar el Saldo Inicial.: ' || sqlerrm;
        p_mensaje     := 'Error al buscar el Saldo Inicial. ';
        p_cod_error   := 3;
        prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
    end;
    -- Busca Saldo Final de la Cuenta
    begin
      select (s.sal_tot_cap - s.sal_ret_ade)
        into v_sal_final
        from ge_sal_diarios s
       where nro_cuenta = c.nro_cuenta
         and fecha = to_date(to_char(it.PAG_CAL.FU_OBT_FEC_ANT_HAB(p_fec_hasta+1, 61, 1), 'DD/MM/YYYY'),'DD/MM/YYYY');
    exception
      when no_data_found then
        v_sal_final := 0;
      when others then
        v_log_mensaje := 'Error al buscar el Saldo Final.: ' || sqlerrm;
        p_mensaje     := 'Error al buscar el Saldo Final. ';
        p_cod_error   := 3;
        prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
    end;
    v_mto_intermedio := v_sal_inicial; -- Se inicia con el monto inicial
    -- Genera la Cabecera del Mensaje MT940
    lp_cab_mensaje;
    -- Si la cta tiene movimientos genera los detalles.
    if v_detalle = 'S' then
      if p_tip_generacion = 'D' then
        for m in c_mov(c.nro_cuenta) loop
          v_nro_transaccion := null;
          v_tipo := m.cod_tip_movimiento;
          -- OMM ENE/2018 Para tener en cuenta reversiones de ATM (no marca como reversado los movimientos
          if m.monto < 0 then
            if v_tipo = 'C' then
              v_tipo := 'D';
            v_des_mov := 'DEBITO EN ';
            else
              v_tipo := 'C';
            v_des_mov := 'CREDITO EN ';
            end if;
          end if;

          IF m.cod_servicio = 419 Then
             v_nro_transaccion := m.nro_transaccion;
          End if;
          
           -- Se agrega nro de referencia externa para transferencias 
          If m.cod_tra_padre in( '388', '303', '346') Then
              Begin
                Select t.ext_id
                  into v_ext_id
                  from ge_dat_transferencias t
                 where t.nro_doc_movimiento = m.nro_documento;
              Exception
                 When others then
                    v_ext_id := null;
              End;
              v_nro_transaccion  := v_ext_id;
          End if;
          
          If v_nro_transaccion is null then
             v_nro_transaccion := to_char(nvl(m.nro_documento, m.nro_documento4));
          End if;
          
          -- 61: Saldo Línea de Operación
          DBMS_LOB.APPEND(v_texto, ':61:' || to_char(m.fecha, 'yymmdd') || substr(to_char(m.fecha, 'yymmdd'), 3, 6) || v_tipo ||
                          replace(ltrim(rtrim(to_char(ABS(m.monto), v_mascara))), '.', ',') || 'NMSC' ||v_nro_transaccion
                          /*nvl(m.nro_documento, m.nro_documento4)*/ || v_salto);

          -- Se agrega la transacción padre al inicio del concepto
          if m.des_transaccion is not null then
            DBMS_LOB.APPEND(v_texto, ':86:' || substr(ltrim(rtrim(upper(TRANSLATE(REPLACE(case when (m.MONTO < 0) then v_des_mov || v_desc_modal
                            else m.des_transaccion end,
                            chr(13), ''), 'áéíóúàèìòùãõâêîôôäëïöüçñÁÉÍÓÚÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇÑ@<>_#-°' ||
                            chr(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))), 1, 35) || v_salto);
          else

            DBMS_LOB.APPEND(v_texto, ':86:' || substr(ltrim(rtrim(upper(TRANSLATE(REPLACE(m.des_tra_padre,
                            chr(13), ''), 'áéíóúàèìòùãõâêîôôäëïöüçñÁÉÍÓÚÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇÑ@<>_#-°' ||
                            chr(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))), 1, 35) || v_salto);
          end if;

          v_cnt_lineas := v_cnt_lineas + 1;
          if m.cod_tip_movimiento = 'C' then
            v_mto_movimiento := v_mto_movimiento + m.monto;
          else
            v_mto_movimiento := v_mto_movimiento - m.monto;
          end if;
        end loop;
      elsif p_tip_generacion = 'A' then
        for m in c_mov_r(c.nro_cuenta) loop
          v_tipo := m.cod_tip_movimiento;
          -- OMM ENE/2018 Para tener en cuenta reversiones de ATM (no marca como reversado los movimientos
          if m.monto < 0 then
            if v_tipo = 'C' then
              v_tipo := 'D';
            v_des_mov := 'DEBITO EN ';
            else
              v_tipo := 'C';
            v_des_mov := 'CREDITO EN ';
            end if;
          end if;
          -- 61: Saldo Línea de Operación
          DBMS_LOB.APPEND(v_texto, ':61:' || to_char(m.fecha, 'yymmdd') || substr(to_char(m.fecha, 'yymmdd'), 3, 6) || v_tipo ||
                          replace(ltrim(rtrim(to_char(ABS(m.monto), v_mascara))), '.', ',') ||
                          'NMSC' || m.cod_transaccion || v_salto);
          -- Se agrega la transacción padre al inicio del concepto
          if m.des_transaccion is not null then
            DBMS_LOB.APPEND(v_texto, ':86:' || substr(ltrim(rtrim(upper(TRANSLATE(REPLACE(case when (m.MONTO < 0) then v_des_mov || v_desc_modal
                            else m.des_transaccion end,
                            chr(13), ''), 'áéíóúàèìòùãõâêîôôäëïöüçñÁÉÍÓÚÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇÑ@<>_#-°' ||
                            chr(9), 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN        ')))), 1, 35) || v_salto);
          end if;

          v_cnt_lineas := v_cnt_lineas + 1;
          if m.cod_tip_movimiento = 'C' then
            v_mto_movimiento := v_mto_movimiento + m.monto;
          else
            v_mto_movimiento := v_mto_movimiento - m.monto;
          end if;
        end loop;
      end if;

      if c.sal_disponible < 0 then
        v_tip_saldo := 'D';
      else
        v_tip_saldo := 'C';
      end if;

      DBMS_LOB.APPEND(v_texto, ':62F:' || v_tip_saldo || v_fec_final || v_cod_moneda ||
                      replace(ltrim(rtrim(to_char(abs(v_sal_final), v_mascara))), '.', ',') || v_salto);

      -- Fin del Mensaje con Movimientos.
      DBMS_LOB.APPEND(v_texto, '-}');
      pr_ins_ge_men_cli_mt940;
    else
      pr_ins_ge_men_cli_mt940;
    end if;
  end loop;

  if v_secuencia = 0 then
    v_log_mensaje := 'No se encontraron datos: ' || sqlerrm;
    p_mensaje     := 'No se encontraron datos ';
    p_cod_error   := 9;
    prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
  end if;

  if p_cod_error != '0' then
    p_cod_error := p_cod_error;
    p_mensaje   := p_mensaje;
  else
    p_cod_error := '0';
    p_mensaje   := 'OK';
  end if;
exception
  when others then
    v_log_mensaje := 'Error en PRG_OBT_MSJ_MT940_V1: ' || sqlerrm;
    p_mensaje     := 'Error en PRG_OBT_MSJ_MT940_V1: ';
    p_cod_error   := 99;
    prg_ins_log_programas('PRG_OBT_MSJ_MT940_V1', v_log_mensaje, null, p_nro_cuenta);
END;
/
