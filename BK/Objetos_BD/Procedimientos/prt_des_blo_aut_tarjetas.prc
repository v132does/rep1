CREATE OR REPLACE PROCEDURE IT.prt_des_blo_aut_tarjetas is
  v_fec_actual    DATE := pag_cal.fu_obt_fec_actual(5);
  rg_ta_blo       ta_blo_aut_tarjetas%rowtype;
  v_cod_modalidad ge_modalidades.cod_modalidad%type;
  -- Realiza, automáticamente, el Desbloqueo de las TCs que fueron Bloqueadas desde el procedimiento      --
  -- PRT_BLO_AUT_TARJETAS, que ya NO cumplen las condiciones por las cuales fueron bloqueadas. Éstas son: --
  -- a. Cuentas de tarjetas que tienen mora mayor a 61 días en otros productos (se verifica que el monto  --
  -- en mora sea mayor a monto mínimo definido por un parámetro dinámico), y                              --
  -- b. Clientes con tarjetas activas de categoría sistema o banco mayor a 3.                             --

  /* Se agrega una condición  más : si la cta. se encuentra parametrizada en
     GE_CTA_DEF_ADICIONALES parámetro 'CTA_DES_AUTORIZADO'
     también permite el desbloqueo que en este caso es a requerimiento.
     -- DE-2489 */

  CURSOR c_consultas IS
    select distinct tb.fecha,
                    tb.cod_persona,
                    tt.nro_cuenta,
                    tb.nro_tarjeta,
                    tb.dat_bloqueo,
                    tb.mot_bloqueo,
                    tb.tip_operacion,
                    tb.estado,
                    tb.log_error
      from ta_blo_aut_tarjetas tb, ta_tarjetas tt, ta_cta_tarjetas tc
     where tb.tip_operacion =
           fug_obt_pardinamico('TIP_OPERACION', 5, TC.COD_MODALIDAD)
       and ( ( tt.nro_cuenta not in
           (select distinct ta.nro_cuenta
              from ta_cta_tarjetas ct, ta_tarjetas ta, ge_cta_clientes g
             where ct.nro_cuenta = ta.nro_cuenta
               and ta.nro_cuenta = g.nro_cuenta
               and ta.cod_persona = g.cod_persona
               and ct.dia_mora < 60
               and ta.cod_estado = 13 --Bloqueada
               and ta.vigente = 'S'
               and g.relacion = 'P'
               and instr(fug_obt_per_entidad,g.cod_persona) = 0
               and ct.mto_mora > fug_obt_pardinamico('MTO_MORA')
               and exists (select 1
                      from ge_cta_clientes t,
                           ge_cuentas      c,
                           ba_modulos      m,
                           ba_monedas      d,
                           ge_est_cuentas  e
                     where t.relacion IN ('P')
                       and t.nro_cuenta = c.nro_cuenta
                       and nvl(c.en_juicio, 'N') = 'N'
                       and c.cod_modulo = m.cod_modulo
                       and nvl(c.dia_atraso, 0) > 60
                       and c.cod_moneda = d.cod_moneda
                       and c.cod_modulo = e.cod_modulo
                       and c.cod_modalidad = e.cod_modalidad
                       and c.estado = e.estado
                       and nvl(e.activo, 'N') = 'S'
                       and t.cod_persona = g.cod_persona)

            union all

            select distinct t.nro_cuenta
              from ge_clientes     gc,
                   ge_cta_clientes cc,
                   ta_tarjetas     t,
                   ta_cta_tarjetas ct
             where gc.cod_persona = cc.cod_persona
               and cc.nro_cuenta = t.nro_cuenta
               and t.nro_cuenta = ct.nro_cuenta
               and t.cod_persona = cc.cod_persona
               and t.cod_estado = 13
               and t.vigente = 'S'
               and cc.relacion = 'P'
               and instr(fug_obt_per_entidad,cc.cod_persona) = 0
               and (pap_cat.fu_obt_cat_crc(gc.cod_persona) > '3' or
                   gc.cat_sistema > 3))    )
               or ( nvl(fug_obt_paradicional(tt.nro_cuenta,'CTA_DES_AUTORIZADO'),'N') = 'S' ) ) --- DE-2489 desbloqueo a requerimiento
       and tb.nro_tarjeta = tt.nro_tarjeta
       and tb.estado = 'E'
       and tt.nro_cuenta = tc.nro_cuenta
       and tt.cod_estado = 13 -- Bloqueado
       and instr(fug_obt_per_entidad,tb.cod_persona) = 0
          -- Cliente no debe estar Inhibido.
       and not exists (select 1
              from ge_per_inhibidas x
             where x.cod_persona = tb.cod_persona
               and nvl(x.estado, 'I') = 'I'
               and rownum = 1);

 CURSOR c_adicionales IS
     select d.fecha,
            d.cod_persona,
            a.nro_cuenta,
            d.nro_tarjeta,
            d.dat_bloqueo,
            d.mot_bloqueo,
            d.tip_operacion,
            d.estado,
            d.log_error,
            a.cod_modalidad
      from ta_cta_tarjetas a, ge_cta_clientes b, ta_tarjetas c, ta_blo_aut_tarjetas d
     where a.nro_cuenta = b.nro_cuenta
       and a.cod_modulo = b.cod_modulo
       and a.cod_modalidad = b.cod_modalidad
       and a.nro_cuenta = c.nro_cuenta
       and b.cod_persona = c.cod_persona
       and c.cod_estado = 13
       and b.relacion = 'A'
       and d.nro_tarjeta = c.nro_tarjeta
       and d.cod_persona = c.cod_persona
       and d.tip_operacion = 1 --Bloqueo
       and d.estado = 'E'
       and not exists (select 1 -- Que no exista un desbloqueo con fecha mayor al bloqueo original
              from ta_blo_aut_tarjetas x
             where x.cod_persona = b.cod_persona
               and x.nro_tarjeta = c.nro_tarjeta
               and x.tip_operacion = 3 -- Desbloqueo
               and x.estado = 'E'
               and x.fecha > d.fecha)
       and ( ( not exists (select 1 -- Que no existan titulares con dias de atrasos
               from ge_cta_clientes e, ge_clientes f, ge_cuentas g, ge_est_cuentas h
              where e.nro_cuenta = b.nro_cuenta
                and e.relacion = 'P'
                and e.cod_persona = f.cod_persona
                and g.nro_cuenta = e.nro_cuenta
                and h.cod_modulo = g.cod_modulo
                and h.cod_modalidad = g.cod_modalidad
                and h.estado = g.estado
                and nvl(h.activo, 'N') = 'S'
                and nvl(g.en_juicio, 'N') = 'N'
                and nvl(g.dia_atraso, 0) > 60
                and (pap_cat.fu_obt_cat_crc(f.cod_persona) > '3' or f.cat_sistema > 3)) )
              or ( nvl(fug_obt_paradicional(c.nro_cuenta,'CTA_DES_AUTORIZADO'),'N') = 'S' )  ); ---DE-2489 desbloqueo a requerimiento

  FUNCTION lf_ver_duplicados(p_nro_tarjeta ta_blo_aut_tarjetas.nro_tarjeta%type)
    RETURN BOOLEAN IS
    v_existe        number;
    v_tip_operacion ta_blo_aut_tarjetas.tip_operacion%type;
  BEGIN

    v_tip_operacion := fug_obt_pardinamico('DES_TIP_OPERACION', 5, v_cod_modalidad);

    select nvl(count(*),0)
      into v_existe
      from ta_blo_aut_tarjetas a
     where a.nro_tarjeta = p_nro_tarjeta
       and exists (select 1
              from ta_blo_aut_tarjetas b
             where b.nro_tarjeta = a.nro_tarjeta
               and b.tip_operacion = v_tip_operacion -- Operaciones de Desbloqueo
               and b.fecha = v_fec_actual);
    IF v_existe = 0 THEN
      -- No hay duplicaciones
      return true;
    ELSE
      return false;
    END IF;
  END;

  -- Carga el archivo e inserta los registros
  PROCEDURE lp_gen_archivo(rg_tbata ta_blo_aut_tarjetas%rowtype) is
  Begin
    insert into ta_blo_aut_tarjetas
      (fecha,
       cod_persona,
       nro_tarjeta,
       mot_bloqueo,
       cod_accion,
       tip_bloqueo,
       tip_operacion,
       amb_bloqueo,
       for_bloqueo,
       cod_motivo,
       usu_actualizacion,
       mes_purga)
    values
      (rg_tbata.fecha,
       rg_tbata.cod_persona,
       rg_tbata.nro_tarjeta,
       rg_tbata.mot_bloqueo,
       rg_tbata.cod_accion,
       rg_tbata.tip_bloqueo,
       rg_tbata.tip_operacion,
       rg_tbata.amb_bloqueo,
       rg_tbata.for_bloqueo,
       rg_tbata.cod_motivo,
       rg_tbata.usu_actualizacion,
       rg_tbata.mes_purga);
    -- Actualiza el estado de la tarjeta a 'Activo'.
    update ta_tarjetas a
       set a.cod_estado = '6'
     where a.nro_tarjeta = rg_tbata.nro_tarjeta;
    -- Actualiza el estado de la cuenta a 'Normal'.
    update ta_cta_tarjetas t
       set t.estado = 'N'
     where t.nro_cuenta =
           (select a.nro_cuenta
              from ta_cta_tarjetas a, ta_tarjetas b
             where a.nro_cuenta = b.nro_cuenta
               and b.nro_tarjeta = rg_tbata.nro_tarjeta
               and b.cod_persona = rg_tbata.cod_persona)
       and t.estado = 'B';
  End;

  PROCEDURE lp_gen_tar_adicionales(p_nro_cuenta in ta_cta_tarjetas.nro_cuenta%type,
                                   p_fecha ta_blo_aut_tarjetas.fecha%type) is


  Begin
     FOR i IN c_adicionales LOOP

          rg_ta_blo.cod_persona       := i.cod_persona;
          rg_ta_blo.nro_tarjeta       := i.nro_tarjeta;
          rg_ta_blo.mot_bloqueo       := to_char(p_fecha,'dd/mm/yyyy')||' - Adicional de la Cuenta ' || p_nro_cuenta;
          rg_ta_blo.cod_accion        := fug_obt_pardinamico('COD_ACCION', 5, i.cod_modalidad);
          rg_ta_blo.tip_bloqueo       := 'A';
          rg_ta_blo.tip_operacion     := fug_obt_pardinamico('DES_TIP_OPERACION', 5, i.cod_modalidad);
          rg_ta_blo.amb_bloqueo       := 'L';
          rg_ta_blo.for_bloqueo       := 'D';
          rg_ta_blo.cod_motivo        := '5';
          rg_ta_blo.usu_actualizacion := '';
          rg_ta_blo.mes_purga         := 998;
          lp_gen_archivo(rg_ta_blo);
      end loop;
    end;


BEGIN
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;

  rg_ta_blo.fecha := v_fec_actual;

  FOR i IN c_consultas LOOP
    begin
      select cod_modalidad
        into v_cod_modalidad
        from ta_cta_tarjetas c
       where c.nro_cuenta = i.nro_cuenta;
    exception
      when no_data_found then
        raise_application_error(-20001, 'Sin modalidad para la cuenta:' || i.nro_cuenta);
      when too_many_rows then
        raise_application_error(-20001, 'Mas de 1 modalidad para la cuenta:' || i.nro_cuenta);
      when others then
        raise_application_error(-20001, 'Error al Obt.modalidad para la cuenta:' || i.nro_cuenta || '-' || sqlerrm);
    end;

    if lf_ver_duplicados(i.nro_tarjeta) then
      --verifica que no se duplique la inserción.
      rg_ta_blo.cod_persona       := i.cod_persona;
      rg_ta_blo.nro_tarjeta       := i.nro_tarjeta;
      rg_ta_blo.mot_bloqueo       := to_char(i.fecha,'dd/mm/yyyy')||' - '||i.mot_bloqueo;
      rg_ta_blo.cod_accion        := fug_obt_pardinamico('COD_ACCION', 5, v_cod_modalidad);
      rg_ta_blo.tip_bloqueo       := 'A';
      rg_ta_blo.tip_operacion     := fug_obt_pardinamico('DES_TIP_OPERACION', 5, v_cod_modalidad);
      rg_ta_blo.amb_bloqueo       := 'L';
      rg_ta_blo.for_bloqueo       := 'D';
      rg_ta_blo.cod_motivo        := '5';
      rg_ta_blo.usu_actualizacion := '';
      rg_ta_blo.mes_purga         := 998;
      lp_gen_archivo(rg_ta_blo);
      lp_gen_tar_adicionales(i.nro_cuenta, i.fecha);
    end if;
  END LOOP;
EXCEPTION
  when others then
    raise_application_error(-20000, 'Error en PRT_DES_BLO_AUT_TARJETAS. ' || SQLERRM);
END PRT_DES_BLO_AUT_TARJETAS;
/

