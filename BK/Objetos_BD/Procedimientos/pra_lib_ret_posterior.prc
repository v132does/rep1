create or replace procedure it.PRA_LIB_RET_POSTERIOR (p_mensaje        in out varchar2,
                                                      p_nro_cuenta     varchar2 default null,
                                                      p_nro_documento  varchar2 default null,
                                                      p_nro_cheque     varchar2 default null)  is
Cursor c1 is Select distinct nro_cuenta, nro_documento
               from ah_retenciones
              where liberado = 'N'
                and lib_posterior = 'S' 
                and usu_modificacion = user
                -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
                and nro_cuenta = p_nro_cuenta
                and nro_documento = p_nro_documento;
--Cursor para liberación por cheques <<EF,08/09/2009>>
Cursor c2 is select 'L' origen,a.nro_documento,a.fec_inicio,a.cod_modulo,
                    a.cod_modalidad,a.cod_moneda,a.cod_oficina,c.cod_retencion,
                    a.nro_cuenta,to_char(c.nro_cheque) nro_cheque,c.cod_banco,
                    c.fecha,c.monto,c.rowid fila_cheque,a.rowid fila_retencion
               from cc_che_enviados c, ah_retenciones a
              where c.nro_boleta = a.nro_documento
                and c.cod_retencion = a.cod_retencion
                and c.nro_cuenta = a.nro_cuenta
                and a.liberado = 'N'
                and (c.estado in ('C','D') or c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL) --Estados a considerar
                and c.liberado = 'N'
                --and a.cod_modalidad in (31,32,41,42)
                and c.lib_posterior = 'S'
                and c.usu_modificacion = user
                -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
                and c.nro_cheque = p_nro_cheque
                --- DYDMR-9450 Incidencia SAU - ITGF - Liberación de Cheques
                and a.nro_cuenta = p_nro_cuenta
                and a.nro_documento = p_nro_documento
              union
             select 'E' origen, a.nro_documento,a.fec_inicio,a.cod_modulo,
                    a.cod_modalidad,a.cod_moneda,a.cod_oficina,g.cod_retencion,
                    a.nro_cuenta,g.nro_cheque,g.cod_banco,
                    g.fecha,g.monto,g.rowid fila_cheque,a.rowid fila_retencion
               from ge_che_exterior g, ah_retenciones a
              where g.nro_boleta = a.nro_documento
                and g.cod_retencion = a.cod_retencion
                and g.nro_cuenta = a.nro_cuenta
                and a.liberado = 'N'
                and g.estado in ('C','D') --Estados a considerar
                and g.liberado = 'N'
                --and a.cod_modalidad in (31,32,41,42)
                and g.lib_posterior = 'S'
                and g.usu_modificacion = user
                -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
                and g.nro_cheque = p_nro_cheque
                --- DYDMR-9450 Incidencia SAU - ITGF - Liberación de Cheques
                and a.nro_cuenta = p_nro_cuenta
                and a.nro_documento = p_nro_documento;
 v_can_liberaciones number(10) := 0;
 v_can_lib_che_local number(10) := 0;
 v_can_lib_che_exterior number(10) := 0;
begin
   begin
     --Cantidad de liberaciones por boleta
     Select count(distinct nro_cuenta)
       into v_can_liberaciones
       from ah_retenciones
      where liberado = 'N'
        and lib_posterior = 'S'
        and usu_modificacion = user
           -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
        and nro_cuenta = p_nro_cuenta
        and nro_documento = p_nro_documento;
   exception
     when no_data_found then
       v_can_liberaciones := 0;
     when others then
       v_can_liberaciones := 0;
   end;
   begin
     --Cantidad de liberaciones x cheque (Plaza Local)
     select count(1)
       into v_can_lib_che_local
       from cc_che_enviados c, ah_retenciones a
      where c.nro_boleta = a.nro_documento
        and c.cod_retencion = a.cod_retencion
        and c.nro_cuenta = a.nro_cuenta
        and a.liberado = 'N'
        and c.estado in ('C', 'D')
        and c.liberado = 'N'
        and c.lib_posterior = 'S'
        and c.usu_modificacion = user
           -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
        and a.nro_cuenta = p_nro_cuenta
        and a.nro_documento = p_nro_documento
        and c.nro_cheque = p_nro_cheque;
   exception
     when no_data_found then
       v_can_lib_che_local := 0;
     when others then
       v_can_lib_che_local := 0;
   end;
   begin
     --Cantidad de liberaciones x cheque (Plaza Extranjera)
     select count(1)
       into v_can_lib_che_exterior
       from ge_che_exterior g, ah_retenciones a
      where g.nro_boleta = a.nro_documento
        and g.cod_retencion = a.cod_retencion
        and g.nro_cuenta = a.nro_cuenta
        and a.liberado = 'N'
        and g.estado in ('C', 'D')
        and g.liberado = 'N'
        and g.lib_posterior = 'S'
        and g.usu_modificacion = user
           -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
        and a.nro_cuenta = p_nro_cuenta
        and a.nro_documento = p_nro_documento
        and g.nro_cheque = p_nro_cheque;
   exception
     when no_data_found then
       v_can_lib_che_exterior := 0;
     when others then
       v_can_lib_che_exterior := 0;
   end;
  --DYDMR-9308 Incidencia SAU - ITGF - Inconveniente en Liberación del TA
/*  If nvl(v_can_liberaciones,0) + nvl(v_can_lib_che_local,0) + nvl(v_can_lib_che_exterior,0) = 0 then
     raise_application_error(-20005, 'No se ha marcado ninguna boleta o cheque para liberar. Verifique');
  End if;*/
  --
  for r1 in c1 loop
     If v_can_liberaciones = 1 then
       pra_lib_retencion(r1.nro_cuenta, r1.nro_cuenta, 'S', 'S',r1.nro_documento);
     Else
       pra_lib_retencion(r1.nro_cuenta, r1.nro_cuenta, 'S', 'N',r1.nro_documento);
     End If;
     commit;
  End Loop;
  Select count(distinct nro_cuenta)
    into v_can_liberaciones
    from ah_retenciones
   where liberado = 'N'
     and lib_posterior = 'S'
     and cod_modulo <> 6
     and usu_modificacion = user
     -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
     and nro_cuenta = p_nro_cuenta
     and nro_documento = p_nro_documento ;
  p_mensaje := null;
  if v_can_liberaciones > 0 then
     p_mensaje := 'Existen depositos que no pudieron ser liberados, porque los cheques aun no fueron confirmados. Verifique!';
     update ah_retenciones
        set lib_posterior = 'N'
      where liberado = 'N'
        and lib_posterior = 'S'
        and usu_modificacion = user
        -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
        and nro_cuenta = p_nro_cuenta
        and nro_documento = p_nro_documento;
     commit;
  end if;

  --Liberaciones por Cheques <<EF,08/09/2009>>
  for r2 in c2 loop
      pra_lib_ret_cheques(r2.origen,r2.nro_cheque,r2.cod_banco,r2.nro_documento,r2.nro_cuenta,r2.fecha,'S');
      commit;
  end loop;

  select count(1)
    into v_can_lib_che_local
    from cc_che_enviados c, ah_retenciones a
   where c.nro_boleta = a.nro_documento
     and c.cod_retencion = a.cod_retencion
     and c.nro_cuenta = a.nro_cuenta
     and a.liberado = 'N'
     and c.estado in ('C','D')
     and c.liberado = 'N'
     and c.lib_posterior = 'S'
     and c.usu_modificacion = user
     -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
     and a.nro_cuenta = p_nro_cuenta
     and a.nro_documento = p_nro_documento
     and c.nro_cheque = p_nro_cheque;

   select count(1)
     into v_can_lib_che_exterior
     from ge_che_exterior g, ah_retenciones a
    where g.nro_boleta = a.nro_documento
      and g.cod_retencion = a.cod_retencion
      and g.nro_cuenta = a.nro_cuenta
      and a.liberado = 'N'
      and g.estado in ('C','D')
      and g.liberado = 'N'
      and g.lib_posterior = 'S'
      and g.usu_modificacion = user
      -- DYDMR-7318 Incidencia SAU - ITGF - Liberacion Anticipada de Cheque COB
      and a.nro_cuenta = p_nro_cuenta
      and a.nro_documento = p_nro_documento
      and g.nro_cheque = p_nro_cheque;


  if v_can_lib_che_local + v_can_lib_che_exterior > 0 then
     p_mensaje := nvl(p_mensaje,' ') || 'Existen cheques que no pudieron ser liberados. Verifique!';
     update cc_che_enviados c
        set c.lib_posterior = 'N'
      where c.estado in ('C','D')
        and c.liberado = 'N'
        and c.lib_posterior = 'S'
        and c.usu_modificacion = user;
     update ge_che_exterior g
        set g.lib_posterior = 'N'
      where g.estado in ('C','D')
        and g.liberado = 'N'
        and g.lib_posterior = 'S'
        and g.usu_modificacion = user;
     commit;
  end if;

end PRA_LIB_RET_POSTERIOR;
/

