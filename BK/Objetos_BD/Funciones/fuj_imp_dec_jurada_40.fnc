CREATE OR REPLACE FUNCTION IT.FUJ_IMP_DEC_JURADA_40
   (p_fecha                in date,
   p_hora                   in varchar2,
   p_cod_usuario            in varchar2,
   p_secuencia              in number default null,
   p_monto                  in number default 0,
   p_cod_transaccion        in ge_movimientos.cod_transaccion%type default null,
   p_nro_ope_pendiente      in lc_ope_pendientes.nro_operacion%type default null,   -- para los casos de operaciones pendientes (246)
   p_cod_tra_padre          in ge_movimientos.cod_tra_padre%type default null,      -- para los casos de operaciones pendientes (246)
   p_cod_modulo             in ge_movimientos.cod_modulo%type default null,         -- para los casos de operaciones pendientes (246)
   p_cod_modalidad          in ge_movimientos.cod_modalidad%type default null,      -- para los casos de operaciones pendientes (246)
   p_cod_mad_padre          in ge_movimientos.cod_mad_padre%type default null,
   p_reimpresion            in varchar2 default 'N')      -- para los casos de operaciones pendientes (246)
   return long is
   v_ancho           number(3) := 40; -- ancho del reporte
   v_resultado      varchar2(4000) := null;
   v_linea          varchar2(200);
   v_monto         varchar2(50);
   v_nombre         varchar2(110);
   v_nom_empresa     varchar2(110);
   v_cuenta         varchar2(15);
   v_cod_oficina   ge_movimientos.cod_oficina%type;
   v_cod_moneda     varchar2(3);
   v_nom_oficina     varchar2(35);
   v_documento       varchar2(20);
   v_ruc            varchar2(20);
   v_tip_persona     varchar2(1);
   v_nacionalidad      varchar2(40);
   v_direccion        varchar2(100);
   v_dir_empresa     varchar2(100);
   v_transaccion     varchar2(60);
   v_cod_tra_padre     number(4);
   v_fecha          varchar2(60);
   v_cod_modulo     varchar2(3);
   v_cod_modalidad   varchar2(3);
   v_ciudad         varchar2(35);
   v_cod_persona     varchar2(10);
   v_cod_mad_padre     number(5);
   v_monto_2           number;
   v_cod_moneda_2      varchar2(3)            := pag_gen.fu_obt_mon_fuerte; -- CRO-JM-03/2015: CROGEFIT-3.  El formulario debe funcionar solo con dólares.
   v_cod_tra_personas    varchar2(2000)       := fug_obt_pardinamico('COD_TRA_FOR_PERSONAS'); --245, NNN
   v_cod_tra_formularios varchar2(2000)       := fug_obt_pardinamico('COD_TRA_FORMULARIOS'); --242,243,NNN

begin
   -- seteo el ancho del reporte
   pag_imp.pr_set_ancho(v_ancho); -- ancho del comprobante

   -- leo los datos del movimiento
   begin
     -- Recupera Datos del Movimiento
     if p_cod_transaccion in ('241','242','243','244','245') then  
-- buscamos los datos por codigo de persona, porque puede darse el caso de que sea una cuenta de cambios:       
           select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,
                                              pag_gen.fu_obt_mon_fuerte,
                                              sum(monto)),
                  (case
                    when p_cod_transaccion = '245' then
                     case
                       when ((select d.nro_cuenta
                                from LC_CTA_CAMBIOS d
                               where d.nro_cuenta = a.nro_cuenta
                               group by d.nro_cuenta) > 0) then
                        null
                       else
                        a.nro_cuenta
                     end
                    else
                     null
                  end) as nro_cuenta,
                  a.cod_moneda,
                  a.cod_tra_padre,
                  a.cod_modulo,
                  a.cod_modalidad,
                  a.cod_mad_padre,
                  cod_ofi_origen,
                  a.cod_persona
             into v_monto_2,
                  v_cuenta,
                  v_cod_moneda,
                  v_cod_tra_padre,
                  v_cod_modulo,
                  v_cod_modalidad,
                  v_cod_mad_padre,
                  v_cod_oficina,
                  v_cod_persona
             from ge_movimientos a
            where fecha = p_fecha
              and hora = p_hora
              and cod_usuario = p_cod_usuario
              and cod_tra_padre not in (517, 598)
              and (nro_secuencia = p_secuencia or p_secuencia is null)
            group by a.nro_cuenta,
                     a.cod_moneda,
                     a.cod_tra_padre,
                     a.cod_modulo,
                     a.cod_modalidad,
                     a.cod_mad_padre,
                     cod_ofi_origen,
                     a.cod_persona;
       elsif p_nro_ope_pendiente is not null then  --si existe una operacion pendiente y no se haya generado aún el movimiento(246)
             begin
               select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,
                                                  pag_gen.fu_obt_mon_fuerte,
                                                  sum(a.monto)),
                      (case
                        when (select count(c.nro_cuenta)
                                from ge_cta_clientes c
                               where c.nro_cuenta = a.nro_cuenta
                                 and c.cod_modulo <> 7
                                 and not exists
                               (select d.nro_cuenta
                                        from LC_CTA_CAMBIOS d
                                       where d.nro_cuenta = c.nro_cuenta
                                       group by d.nro_cuenta)
                               group by c.nro_cuenta) > 0 then
                         a.nro_cuenta
                        when (select count(c.nro_cuenta)
                                from ge_cta_clientes c
                               where c.nro_cuenta = a.cta_referencia
                                 and c.cod_modulo <> 7
                                 and not exists
                               (select d.nro_cuenta
                                        from LC_CTA_CAMBIOS d
                                       where d.nro_cuenta = c.nro_cuenta
                                       group by d.nro_cuenta)
                               group by c.nro_cuenta) > 0 then
                         a.cta_referencia
                        when (select count(c.nro_cuenta)
                                from ge_cta_clientes c
                               where c.nro_cuenta = a.cta_ref_contra3
                                 and c.cod_modulo <> 7
                                 and not exists
                               (select d.nro_cuenta
                                        from LC_CTA_CAMBIOS d
                                       where d.nro_cuenta = c.nro_cuenta
                                       group by d.nro_cuenta)
                               group by c.nro_cuenta) > 0 then
                         a.cta_ref_contra3
                        else
                         null
                      end) as nro_cuenta,
                      a.cod_moneda,
                      a.cod_oficina,
                      (case
                        when (select count(c.nro_cuenta)
                                from ge_cta_clientes c
                               where c.nro_cuenta = a.nro_cuenta
                                 and exists
                               (select d.nro_cuenta
                                        from LC_CTA_CAMBIOS d
                                       where d.nro_cuenta = c.nro_cuenta
                                       group by d.nro_cuenta)
                               group by c.nro_cuenta) > 0 then
                         a.cod_persona
                        when (select count(c.nro_cuenta)
                                from ge_cta_clientes c
                               where c.nro_cuenta = a.cta_referencia
                                 and exists
                               (select d.nro_cuenta
                                        from LC_CTA_CAMBIOS d
                                       where d.nro_cuenta = c.nro_cuenta
                                       group by d.nro_cuenta)
                               group by c.nro_cuenta) > 0 then
                         a.cod_persona
                        when (select count(c.nro_cuenta)
                                from ge_cta_clientes c
                               where c.nro_cuenta = a.cta_ref_contra3
                                 and exists
                               (select d.nro_cuenta
                                        from LC_CTA_CAMBIOS d
                                       where d.nro_cuenta = c.nro_cuenta
                                       group by d.nro_cuenta)
                               group by c.nro_cuenta) > 0 then
                         a.cod_persona
                        else
                         null
                      end) as cod_persona
                 into v_monto_2,
                      v_cuenta,
                      v_cod_moneda,
                      v_cod_oficina,
                      v_cod_persona
                 from lc_ope_pendientes a
                where a.nro_operacion = p_nro_ope_pendiente
                group by a.nro_cuenta,
                         a.cod_moneda,
                         a.cta_referencia,
                         a.cta_ref_contra3,
                         a.cod_oficina,
                         a.cod_persona;
             exception
               when others then
                 v_monto_2     := null;
                 v_cuenta      := null;
                 v_cod_moneda  := null;
                 v_cod_oficina := null;
                 v_cod_persona := null;
             end;
                  v_cod_tra_padre := p_cod_tra_padre;
                  v_cod_modulo    := p_cod_modulo;
                  v_cod_modalidad := p_cod_modalidad;
                  v_cod_mad_padre := p_cod_mad_padre;
       elsif (p_cod_transaccion = '246' and p_reimpresion = 'S') then -- solo en caso de reimpresion:
          -- usaremos el equivalente en Gs. porque existe diferencias para llegar a USD si utilizamos EUR
          Select pag_gen.fu_con_mon_a_moneda(g.cod_moneda,
                                              pag_gen.fu_obt_mon_fuerte,
                                              sum(g.monto)),
                 (case when ((select d.nro_cuenta
                                from LC_CTA_CAMBIOS d
                               where d.nro_cuenta = g.nro_cuenta
                               group by d.nro_cuenta) > 0) then
                        null
                       else
                        g.nro_cuenta
                     end) as nro_cuenta,
                 g.cod_moneda,
                 g.cod_tra_padre,
                 g.cod_modulo,
                 g.cod_modalidad,
                 g.cod_mad_padre,
                 g.cod_ofi_origen,
                 g.cod_persona
            into v_monto_2,
                 v_cuenta,
                 v_cod_moneda,
                 v_cod_tra_padre,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_mad_padre,
                 v_cod_oficina,
                 v_cod_persona
            from ge_movimientos g
           where g.fecha = p_fecha
             and g.hora = p_hora
             and g.cod_usuario = p_cod_usuario
             and g.nro_cuenta is not null
             AND g.reversado = 'N' --reversadas no
             and g.nro_cuenta = (case -- aquí elegimos si existe una cuenta distinta a la cuenta de cambios del banco, sino elegimos esa cuenta de cambios:
                                 when ((select count(a.nro_cuenta)
                                          from ge_movimientos a
                                         where a.fecha = g.fecha
                                           and a.cod_usuario = g.cod_usuario
                                           and a.hora = g.hora
                                           and a.nro_cuenta is not null
                                           and not exists
                                         (select b.nro_cuenta
                                                  from LC_CTA_CAMBIOS b
                                                 where a.nro_cuenta = b.nro_cuenta)) > 0) then
                                  (select a.nro_cuenta
                                     from ge_movimientos a
                                    where a.fecha = g.fecha
                                      and a.cod_usuario = g.cod_usuario
                                      and a.hora = g.hora
                                      and a.nro_cuenta is not null
                                      and not exists
                                    (select b.nro_cuenta
                                             from LC_CTA_CAMBIOS b
                                            where b.nro_cuenta = a.nro_cuenta)
                                      and a.nro_secuencia =
                                          (select min(c.nro_secuencia)
                                             from ge_movimientos c
                                            where c.cod_usuario = a.cod_usuario
                                              and c.hora = a.hora
                                              and c.fecha = a.fecha
                                              and c.nro_cuenta is not null
                                              and not exists
                                            (select b.nro_cuenta
                                                     from LC_CTA_CAMBIOS b
                                                    where b.nro_cuenta = c.nro_cuenta))
                                    group by a.nro_cuenta)
                                 else
                                  (select a.nro_cuenta
                                     from ge_movimientos a
                                    where a.fecha = g.fecha
                                      and a.cod_usuario = g.cod_usuario
                                      and a.hora = g.hora
                                      and a.nro_cuenta is not null
                                      and exists (select b.nro_cuenta
                                             from LC_CTA_CAMBIOS b
                                            where a.nro_cuenta = b.nro_cuenta)
                                    group by a.nro_cuenta)
                               end)
                         group by g.nro_cuenta,
                                  g.cod_moneda,
                                  g.cod_tra_padre,
                                  g.cod_modulo,
                                  g.cod_modalidad,
                                  g.cod_mad_padre,
                                  g.cod_ofi_origen,
                                  g.cod_persona;
       --350 nos interesa solo modalidad 91 -> caja                           
       elsif p_cod_transaccion in ('350','351') then 
             select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,
                                              pag_gen.fu_obt_mon_fuerte,
                                              sum(monto)),
                  a.nro_cuenta,
                  a.cod_moneda,
                  a.cod_tra_padre,
                  a.cod_modulo,
                  a.cod_modalidad,
                  a.cod_mad_padre,
                  cod_ofi_origen
             into v_monto_2,
                  v_cuenta,
                  v_cod_moneda,
                  v_cod_tra_padre,
                  v_cod_modulo,
                  v_cod_modalidad,
                  v_cod_mad_padre,
                  v_cod_oficina
             from ge_movimientos a
            where fecha = p_fecha
              and hora = p_hora
              and a.cod_mad_padre = 91              
              and cod_usuario = p_cod_usuario
              and cod_tra_padre not in (517, 598)
              and (nro_secuencia = p_secuencia or p_secuencia is null)
            group by a.nro_cuenta,
                     a.cod_moneda,
                     a.cod_tra_padre,
                     a.cod_modulo,
                     a.cod_modalidad,
                     a.cod_mad_padre,
                     cod_ofi_origen;
       else
         select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,
                                              pag_gen.fu_obt_mon_fuerte,
                                              sum(monto)),
                  a.nro_cuenta,
                  a.cod_moneda,
                  a.cod_tra_padre,
                  a.cod_modulo,
                  a.cod_modalidad,
                  a.cod_mad_padre,
                  cod_ofi_origen
             into v_monto_2,
                  v_cuenta,
                  v_cod_moneda,
                  v_cod_tra_padre,
                  v_cod_modulo,
                  v_cod_modalidad,
                  v_cod_mad_padre,
                  v_cod_oficina
             from ge_movimientos a
            where fecha = p_fecha
              and hora = p_hora
              and cod_usuario = p_cod_usuario
              and cod_tra_padre not in (517, 598)
              and (nro_secuencia = p_secuencia or p_secuencia is null)
            group by a.nro_cuenta,
                     a.cod_moneda,
                     a.cod_tra_padre,
                     a.cod_modulo,
                     a.cod_modalidad,
                     a.cod_mad_padre,
                     cod_ofi_origen;
       end if;
     -- Recupera Datos de la Cuenta
     if (v_cod_persona is not null) or (v_cuenta is not null) then
         select distinct
                b.descripcion, substr(d.nom_completo,1,110), d.nro_documento, d.tipo, e.nacionalidad,
                substr(nvl(f.direccion||decode(numero,null,'',' '||numero),' '),1,30),
                d.cod_persona
           into v_nom_oficina, v_nombre, v_documento,
                v_tip_persona, v_nacionalidad, v_direccion,
                v_cod_persona
         from ba_oficinas b, ge_cta_clientes c,
               ba_personas d, ba_paises e, ba_direcciones f
          where b.cod_oficina = v_cod_oficina
            and (c.nro_cuenta = v_cuenta or v_cuenta is null)  -- CRO-JM-03/2015: CROGEFIT-3
            and (c.cod_persona = v_cod_persona or v_cod_persona is null)
            and c.relacion = 'P'
            and c.cod_persona = d.cod_persona
            and d.cod_pais = e.cod_pais
            and d.cod_persona = f.cod_persona(+)
            and 'S' = f.principal(+);
      else
          Raise_application_error(-20001, 'No se encontró número de cuenta o código cliente ');
      end if;
      --
      v_fecha := fug_des_fecha(p_fecha);
      --
  exception
     when no_data_found then
           select pag_gen.fu_con_mon_a_moneda(a.cod_moneda,
                                              pag_gen.fu_obt_mon_fuerte,
                                              g.monto),
                a.nro_cuenta, g.cod_moneda,
                b.descripcion, substr(d.nom_completo,1,110), d.nro_documento, d.tipo, e.nacionalidad,
                nvl(f.direccion||decode(numero,null,'',' '||numero),' '), g.cod_tra_padre, fug_des_fecha(p_fecha), g.cod_modulo,
                g.cod_modalidad, d.cod_persona, g.cod_mad_padre
                into v_monto_2, v_cuenta, v_cod_moneda, v_nom_oficina, v_nombre, v_documento,
                v_tip_persona, v_nacionalidad, v_direccion, v_cod_tra_padre, v_fecha, v_cod_modulo,
                v_cod_modalidad, v_cod_persona, v_cod_mad_padre
                from ba_oficinas b, ba_personas d, ba_paises e, ba_direcciones f,
                     ge_movimientos g,
                     (select cod_modulo, cod_modalidad, nro_cuenta,
                             cod_mad_padre, cod_tra_padre, cod_ofi_origen,
                             cod_moneda, sum(monto) monto, to_char(nro_documento2) cod_persona
                        from ge_movimientos
                       where fecha = p_fecha
                         and hora = p_hora
                         and cod_usuario = p_cod_usuario
                         and cod_transaccion = 760
                       group by cod_modulo, cod_modalidad, nro_cuenta, cod_moneda,
                             cod_mad_padre, cod_tra_padre, cod_ofi_origen, to_char(nro_documento2)
                     ) a
                where g.cod_ofi_origen = b.cod_oficina
                and a.cod_persona = d.cod_persona
                and d.cod_pais = e.cod_pais
                and g.fecha = p_fecha
                and g.hora = p_hora
                and g.cod_usuario = p_cod_usuario
                and g.nro_secuencia = 1
                and d.cod_persona = f.cod_persona(+)
                and 'S' = f.principal(+);
     when too_many_rows then 
           raise_application_error(-20000,'Se retorno mas de un movimiento'||sqlerrm);
     when others then
           raise_application_error(-20000,'Error al leer el movimiento'||sqlerrm);
  end;
  if p_reimpresion = 'S' then
     v_monto := '***'||trim(to_char((nvl(p_monto,0)),'999,999,999,999,999.99'));
  else
     v_monto := '***'||trim(to_char((nvl(v_monto_2,0) + nvl(p_monto,0)),'999,999,999,999,999.99'));
  end if;
  -- recupero la descripcion cod_tra_padre
  begin
      select descripcion
      into v_transaccion
      from ge_transacciones
      where cod_transaccion = v_cod_tra_padre
        and cod_modalidad = v_cod_mad_padre;
  exception
     when others then
           raise_application_error(-20000,'Error al recuperar descripcion transaccion'||sqlerrm);
           
  end;

  -- recupero la ciudad de la direccion
  begin
      select a.descripcion
      into v_ciudad
      from ba_ciudades a, ba_direcciones b
      where a.cod_ciudad = b.cod_ciudad
      and b.cod_persona = v_cod_persona
      and b.principal = 'S'
      and b.cod_pais = a.cod_pais;
  exception
     when no_data_found then
           v_ciudad:='.';
     when others then
           raise_application_error(-20000,'Error al recuperar nombre de ciudad'||sqlerrm);
  end;


  --Detalle de Impresion
   pag_imp.PR_CONDENSADO(v_resultado,'S'); -- activa impresion condensada
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
   --pag_imp.pr_imp_linea(v_resultado, '      ANEXO RESOLUCION No. 245/97', 1, 1);
   --pag_imp.pr_imp_linea(v_resultado, '      INFORME SOBRE TRANSACCIONES', 1, 1);
  pag_imp.pr_imp_linea(v_resultado, '      ANEXO RESOLUCION Nro.  60/10', 1, 1);
  pag_imp.pr_imp_linea(v_resultado, '      REGISTRO SOBRE TRANSACCIONES', 1, 1);
   pag_imp.pr_imp_linea(v_resultado, '1-) IDENTIDAD DEL INDIVIDUO QUE SE PRE', 2, 0);
   pag_imp.pr_imp_linea(v_resultado, 'SENTA A REALIZAR LA OPERACION', 1, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
   pag_imp.pr_imp_linea(v_resultado, rpad('Nombres y Apellidos: ',80,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Dto.Ident. Presentado Nro: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('R.U.C. Nro: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Nacionalidad: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Ocupacion o Ramo del Negocio: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('.',40,'.'), 1, 0);

   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
   pag_imp.pr_imp_linea(v_resultado, '2-) PERSONA POR CUYA ORDEN SE REALIZA LA', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'TRANSACCION', 1, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
   if v_tip_persona = 'J' then
    v_nom_empresa := v_nombre;
    v_nombre := '.';
    v_ruc := v_documento;
    v_documento := '.';
    v_dir_empresa := v_direccion;
    v_direccion := '.';
    v_nacionalidad := '.';

--    pag_imp.pr_imp_linea(v_resultado, 'Si el ORDENANTE fuese una EMPRESA:', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Nombre de la Empresa: '||v_nom_empresa, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'R.U.C. Nro: '||v_ruc, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: '||v_dir_empresa,40,'.'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Actividad: ',40,'.'), 1, 0);
  else
--    pag_imp.pr_imp_linea(v_resultado, 'Si el ORDENANTE fuese mas de una persona', 1, 0);
--    pag_imp.pr_imp_linea(v_resultado, 'indicar el principal', 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Nombres y Apellidos: '||v_nombre, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Dto.Ident. Presentado Nro: '||v_documento,40,'.'), 1, 0);
--    pag_imp.pr_imp_linea(v_resultado, rpad('R.U.C. Nro: ',40,'.'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, 'Nacionalidad: '||v_nacionalidad, 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Direccion: '||v_direccion,40,'.'), 1, 0);
    pag_imp.pr_imp_linea(v_resultado, rpad('Ciudad: '||v_ciudad,40,'.'), 1, 0);
  end if;
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
   pag_imp.pr_imp_linea(v_resultado, '3-) MOVIMIENTOS EN CUENTA(S)', 2, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
   pag_imp.pr_imp_linea(v_resultado, rpad('Ingresos: ',40,'.'), 1, 0);
   pag_imp.pr_imp_linea(v_resultado, rpad('Egresos: ',40,'.'), 1, 0);
  if v_cod_modulo = 3 then
     if v_cod_modalidad = 31 then--Ahorro Vista
        pag_imp.pr_imp_linea(v_resultado, rpad('Dep. de Ahorro Nro: '||v_cuenta,40,'.'), 1, 0);
     elsif v_cod_modalidad in (33,35) then--Certificados
        pag_imp.pr_imp_linea(v_resultado, rpad('Dep. a Plazo Fijo Nro: '||v_cuenta,40,'.'), 1, 0);
     end if;
  elsif v_cod_modulo = 4 or v_cod_modulo = 7 then
     if v_cod_modalidad = 41 or v_cod_modalidad = 71 then--Cuentas Corrientes
        pag_imp.pr_imp_linea(v_resultado, rpad('Cta.Cte.Nros: '||v_cuenta,40,'.'), 1, 0);
     end if;
  elsif v_cod_modulo = 6 then--Prestamos
      pag_imp.pr_imp_linea(v_resultado, rpad('Prestamos: '||v_cuenta,40,'.'), 1, 0);
  end if;
   pag_imp.pr_imp_linea(v_resultado, rpad('Otros: ',40,'.'), 1, 0);
   pag_imp.pr_negrita(v_resultado,'S'); -- Prende negrita
   pag_imp.pr_imp_linea(v_resultado, '4-) TIPOS DE TRANSACCIONES Y MONTOS', 2, 0);
   pag_imp.pr_negrita(v_resultado,'N'); -- Apaga la negrita
  pag_imp.pr_imp_linea(v_resultado, rpad('Monto de la Transaccion: ',40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad(v_cod_moneda_2||': '||v_monto,40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad(v_transaccion,40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'Fecha de Transaccion: ', 1,0);
  pag_imp.pr_imp_linea(v_resultado, v_fecha, 1,0);
  --pag_imp.pr_imp_linea(v_resultado, 'ESTE FORMULARIO TIENE CARACTER DE DECLA', 2, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'RACION JURADA Y SEGUN RESOLUCION No.2,', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'ACTA No.84  DE FECHA 02 DE MAYO DE 1997', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'DEL DIRECTORIO DEL BANCO CENTRAL DEL PA', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'RAGUAY DEBE SER LLENADO POR CADA OPERA', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'CION EN DOLARES O EQUIVALENTE EN OTRAS', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, 'MONEDAS CUYO MONTO SERA SUPERIOR A USD', 1, 0);
  --pag_imp.pr_imp_linea(v_resultado, '10,000.00-(DIEZ MIL)', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'ESTE FORMULARIO TIENE CARACTER DE DECLA', 2, 0);
   pag_imp.pr_imp_linea(v_resultado,'RACION JURADA Y SEGUN RESOLUCION Nro.', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, '349/2013 DE LA SECRETARIA DE PREVENCION ', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'DE LAVADO DE DINERO O BIENES (SEPRELAD) ' , 1, 0);
   pag_imp.pr_imp_linea(v_resultado,'DEBE SER LLENADO POR CADA OPERACION CUYO', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'IMPORTE EN FORMA UNICA,FRACCIONADA O ' , 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'MULTIPLE, SEA SUPERIOR A USD', 1, 0);
   pag_imp.pr_imp_linea(v_resultado,
          to_char(fug_obt_pardinamico('OPE_SUP_MON_FUERTE'),'999g999g999d00')||'-('||
          upper(fue_obt_denominacion(fug_obt_pardinamico('OPE_SUP_MON_FUERTE')))||') ', 1, 0);
   pag_imp.pr_imp_linea(v_resultado, 'O SU EQUIVALENTE EN OTRAS MONEDAS', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'Se deja constancia que la informacion', 2, 0);
  pag_imp.pr_imp_linea(v_resultado, 'proveida en este formulario ha sido obte', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'nida de documentos exhibidos y datos pro', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'veidos por los declarantes de la presen', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'te transaccion sin que la ENTIDAD OPERAN', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'TE, por tanto, asuma responsabilidad al', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'guna acerca de la autenticidad de los', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'mismos', 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Firma del Declarante(s) ',40,'.'), 2, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Aclaracion de Firma(s)',40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('.',40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, 'Lugar y Fecha: ', 2, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad(v_nom_oficina||', '||v_fecha||' ',40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, rpad('Sello y Firma de la Entidad',40,'.'), 1, 0);
  pag_imp.pr_imp_linea(v_resultado, ' ', 18, 0);

  --v_resultado:=LENGTH(v_resultado);
  return(v_resultado);
exception
  when others then
      --raise_application_error(-20000,'Declaracion Jurada '||sqlerrm);
      return null;
end FUJ_IMP_DEC_JURADA_40;
/

