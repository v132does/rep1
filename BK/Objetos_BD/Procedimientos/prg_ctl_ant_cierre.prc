CREATE OR REPLACE PROCEDURE IT.PRG_CTL_ANT_CIERRE IS
  v_existe varchar2(1);
  v_error  varchar2(4000) := '';
  v_dir_correo varchar2(500);
  v_db_name    varchar2(100);

procedure lp_mensaje_error(p_msj_error in varchar2) is
begin
  if v_error is null then
    v_error := p_msj_error;
  else
    v_error := substr(v_error || chr(10) || p_msj_error, 0, 4000);
  end if;
end;

BEGIN
--VERIFICA SI EXISTE REGISTRADA LA COTIZACION DE LA MOENDA FUERTE
BEGIN
   SELECT 'S'
     INTO v_existe
     FROM ge_cotizaciones f
    WHERE f.cod_moneda = pag_gen.fu_obt_mon_fuerte
      AND f.fecha = fue_obt_fec_calendar(1);
EXCEPTION
   WHEN no_data_found THEN
      lp_mensaje_error('No se encuentra registrada la cotización de la moneda fuerte del día. Verifique!');
END;


  -- VERIFICA SI NO HAY PROBLEMA CON EL CLIENTE PRINCIPAL
  declare
    cursor c_mov is
    select distinct nro_cuenta, cod_modulo, cod_modalidad, cod_oficina
      from ge_movimientos
     where nro_cuenta is not null;
  begin
    for reg in c_mov loop
      begin
        select 'S'
          into v_existe
          from ge_cta_clientes gcc,
               ge_clientes     gc
         where gcc.nro_cuenta = reg.nro_cuenta
           and gcc.relacion = 'P'
           and gcc.cod_persona = gc.cod_persona
           and gcc.cod_modulo = reg.cod_modulo
           and gcc.cod_modalidad = reg.cod_modalidad
           and gcc.cod_oficina = reg.cod_oficina;
      exception
        when no_data_found then
          lp_mensaje_error('Cta.sin Cliente Principal : ' || reg.nro_cuenta ||
                           ' Mod. '   || reg.cod_modulo ||
                           ' Modal. ' || reg.cod_modalidad ||
                           ' Ofi. '   || reg.cod_oficina);
       when too_many_rows then
          lp_mensaje_error('Cta.con Clie.Princ. duplicado: ' || reg.nro_cuenta ||
                           ' Mod. '   || reg.cod_modulo ||
                           ' Modal. ' || reg.cod_modalidad ||
                           ' Ofi. '   || reg.cod_oficina);
      end;
    end loop;
  end;
  -- VERIFICA QUE SOLO EXISTA UNA TARJETA PRINCIPAL POR PERSONA
  begin
    select decode(count(*),0,'N','S')
      into v_existe
      from
      (select  a.nro_cuenta, a.cod_persona, count(*) cantidad
              from ta_tarjetas a
              where a.vigente = 'S'
            and exists (select 0
                          from ge_cta_clientes c
                         where c.nro_cuenta = a.nro_cuenta
                           and c.cod_persona = a.cod_persona
                           and c.cod_modulo = 5
                           and c.relacion = 'P'
                         group by c.nro_cuenta, c.cod_persona
                         having count(*) > 1)
              group by a.nro_cuenta, a.cod_persona
              having count(*) > 1);
    if v_existe = 'S' then
       lp_mensaje_error('Existen clientes con más de una tarjeta vigente. Verifique!');
    end if;
   exception
      when others then
       lp_mensaje_error('Error en verificación de clientes con más de una tarjeta vigente. Verifique!');
  end;
  -- VERIFICA SI EXISTE LA RUTINA1
  declare
    cursor c_mov is
    select distinct m.cod_transaccion, m.cod_modulo, m.cod_modalidad, m.cod_oficina, t.rutina1
      from ge_movimientos   m,
           ge_transacciones t
     where not exists (select 1
                         from all_procedures
                        where owner = 'IT'
                          and object_name = t.rutina1)
       and t.rutina1 is not null
       and m.cod_modulo = t.cod_modulo
       and m.cod_modalidad = t.cod_modalidad
       and m.cod_transaccion = t.cod_transaccion
       and m.nro_cuenta is not null;
  begin
    for reg in c_mov loop
      lp_mensaje_error('No existe la rutina para la transaccion : ' || reg.cod_transaccion ||
                       ' Mod. '   || reg.cod_modulo ||
                       ' Modal. ' || reg.cod_modalidad ||
                       ' Rutina1 ' || reg.rutina1);
    end loop;
  end;
  -- VERIFICA MOVIMIENTO SIN OFICINA
  declare
    cursor c_mov is
    select m.fecha, m.hora, m.cod_usuario, m.nro_secuencia
      from ge_movimientos   m,
           ge_transacciones t
     where m.cod_modulo = t.cod_modulo(+)
       and m.cod_modalidad = t.cod_modalidad(+)
       and m.cod_transaccion = t.cod_transaccion(+)
       and m.cod_oficina is null
       and (exists (select 1
                      from ge_tip_asientos a
                     where a.cod_tip_asiento = t.cod_tip_asiento) or
            exists (select 1
                      from ge_tip_asientos a
                     where a.cod_tip_asiento = t.cod_tip_asiento2) or
            m.cod_rubro is not null);
  begin
    for reg in c_mov loop
      lp_mensaje_error('Movimiento sin oficina :' ||
                       ' Fecha. ' || reg.fecha ||
                       ' Hora. '  || reg.hora ||
                       ' Usu. '   || reg.cod_usuario ||
                       ' Sec. '   || reg.nro_secuencia);
    end loop;
  end;
  -- VERIFICA SI HAY GARANTIA NO REGISTRADA
  declare
    cursor c_mov is
    select c.nro_cuenta, c.cod_modalidad, x.nro_garantia, x.mto_aplicado
      from ge_cuentas c,
           (select cg.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado
              from pr_cta_garantias cg
             where (cg.cod_garantia not in (1,2,42)
                    and instr(fug_obt_pardinamico('PRE_TIP_GAR_SOLA_FIRMA')||',',cg.cod_garantia||',')= 0 )
               and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia)
             union all
            select s.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado
              from cc_lin_sob_garantias cg,
                   cc_lin_sobregiros    s
             where cg.cod_garantia not in (1,2,42)
               and cg.nro_secuencia = s.nro_sec_padre
               and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia)
             union all
            select cg.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado
              from ta_cta_garantias cg
             where cg.cod_garantia not in (1,2,42)
               and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia)
             union all
            select cg.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado
              from cx_cta_garantias cg
             where cg.cod_garantia not in (1,2,42)
               and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia)) x
     where c.nro_cuenta = x.nro_cuenta;
  begin
    for reg in c_mov loop
      lp_mensaje_error('Garantia no registrada :' ||
                       ' Cuenta. '       || reg.nro_cuenta ||
                       ' Modalidad. '    || reg.cod_modalidad ||
                       ' Nro.Garantia. ' || reg.nro_garantia);
    end loop;
  end;
  --Controla que el interes no sea diferente al interes devengado no cobrado.
 DECLARE
    CURSOR c_prestamos IS
       SELECT nro_cuenta,
              (sal_interes + sal_int_adelantado - val_int_devengar) sal_interes,
              (dev_no_cobrado + dev_suspenso) dev_no_cobrado
         FROM pr_cta_prestamos
        WHERE estado NOT IN ('N', 'I')
          AND (sal_interes + sal_int_adelantado - val_int_devengar) <>
              (dev_no_cobrado + dev_suspenso);
 BEGIN
    FOR reg IN c_prestamos LOOP
       lp_mensaje_error('Diferencia en Interés Devengado no Cobrado: ' || 'Cuenta: ' ||
                        reg.nro_cuenta || ' Mto. Interes: ' || reg.sal_interes ||
                        ' Mto. Int. Dev. no Cobrado: ' || reg.dev_no_cobrado);
    END LOOP;
 END;
 DECLARE
    v_sal_cta_bancaria cc_cta_bancarias.sal_total%type;
 BEGIN
    IF fug_obt_pardinamico('PRE_OBT_PTO_COBRANZA') = 'S' AND
       fug_obt_pardinamico('PRE_CTA_BAN_INVERFIN') IS NOT NULL THEN
       pag_cta.pr_obt_cuenta(fug_obt_pardinamico('PRE_CTA_BAN_INVERFIN'));
       v_sal_cta_bancaria := pag_cta.fu_sal_total;
       if v_sal_cta_bancaria < 0 then
          lp_mensaje_error('Saldo de la cuenta bancaria '||fug_obt_pardinamico('PRE_CTA_BAN_INVERFIN')||
                           ' en negativo, saldo: ' ||v_sal_cta_bancaria);
       end if;
    END IF;
 END;


  -- SI HAY MENSAJES DE ERROR
  if v_error is not null then
    -- Obtiene la direccion de correo del operador
    begin
      select u.dir_correo
        into v_dir_correo
        from ba_usuarios u
       where u.cod_usuario = substr(user, 1, 10);
    exception
      when others then
        raise_application_error(-20000, 'Problema al obtener la direccion de correo del operador');
    end;
    -- Obtiene el nombre de la base de datos

    select UPPER(SYS_CONTEXT('USERENV', 'DB_NAME'))
      into v_db_name
      from dual;
    -- Envia el mail
    it_mail.mail (fug_obt_dir_correo,
                  v_dir_correo,
                  'Problemas en Control Antes del Cierre - BD: ' || v_db_name,
                  substr(v_error,1,3000));

    raise_application_error(-20000, 'Existen problemas en los datos. Verifique su correo');
  end if;

EXCEPTION
  WHEN OTHERS THEN
    -- hay problemas en el proceso
    raise_application_error(-20000, 'PRG_CTL_ANT_CIERRE: ' || chr(13) || sqlerrm);
END PRG_CTL_ANT_CIERRE;
/

