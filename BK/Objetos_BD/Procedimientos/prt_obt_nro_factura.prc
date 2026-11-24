create or replace procedure it.PRT_OBT_NRO_FACTURA( p_cod_persona GE_CLIENTES.COD_PERSONA%TYPE DEFAULT NULL ) is

  v_nro_factura     ge_impuestos.nro_tarjeta%type := null;
  v_old_nro_cuenta  ge_impuestos.nro_cuenta%type := null;
  v_lim_items       number(2);
  v_can_items       number(2) := 0;
  v_can_facturas    number(10);
  v_tot_facturas    number(10);
  v_nro_cuenta      ge_impuestos.nro_cuenta%type;
  v_cod_persona     ba_personas.cod_persona%type;

  cursor cuentas is
    select nro_tarjeta,g.rowid
      from ge_impuestos g
      where g.nro_cuenta is null
        and g.nro_cta_aho is null
        and g.nro_factura is null
        and ( p_cod_persona IS NULL OR EXISTS( select 1
                                                 from ta_cta_tarjetas tar,
                                                      ge_cta_clientes cta,
                                                      ta_tarjetas ta
                                                where ta.nro_tarjeta = g.nro_tarjeta
                                                  and ta.nro_cuenta  = tar.nro_cuenta
                                                  and tar.nro_cuenta = cta.nro_cuenta
                                                  and cta.relacion = 'P'
                                                  and cta.cod_persona = p_cod_persona ) )
    order by nro_tarjeta;

  cursor tarjetas is
   select t.nro_cuenta, t.rowid
     from ge_impuestos t,
          ta_tarjetas tar
    where t.nro_tarjeta = tar.nro_tarjeta
      and t.nro_factura is null
      and t.nro_cuenta is not null
      and t.cod_persona = nvl( p_cod_persona, t.cod_persona )
   order by t.nro_cuenta
   for update nowait;

begin
  IF fug_obt_tip_implementacion = 2 THEN
    v_lim_items := 10;
  ELSE
    v_lim_items := 13;
  END IF;
  --Asignar nro. de cuenta a las tarjetas
  for j in cuentas loop
    begin
      select cta.nro_cuenta,cta.cod_persona
        into v_nro_cuenta,v_cod_persona
        from ta_cta_tarjetas tar,
             ge_cta_clientes cta,
             ta_tarjetas ta
        where ta.nro_tarjeta = j.nro_tarjeta
          and ta.nro_cuenta  = tar.nro_cuenta
          and tar.nro_cuenta = cta.nro_cuenta
          and cta.relacion = 'P';
    exception
      when others then
        v_nro_cuenta := null;
    end;
    If v_nro_cuenta is not null then
      Update ge_impuestos
         set nro_cuenta = v_nro_cuenta,
             cod_persona = v_cod_persona
       where rowid = j.rowid;
    End if;
  end loop;

  --Obtener la cantidad de facturas a utilizar
  select sum( decode( round( xx_registros / v_lim_items, 1 ), trunc( xx_registros / v_lim_items ), trunc( xx_registros / v_lim_items ), trunc( xx_registros / v_lim_items ) + 1 ) )
    into v_can_facturas
    from ( select imp.nro_cuenta xx_nro_cuenta, count(*) xx_registros
             from ge_impuestos imp,
                  ta_tarjetas tar
            where imp.nro_factura is null
              and imp.nro_tarjeta = tar.nro_tarjeta
              and imp.nro_cuenta is not null
              and imp.cod_persona = nvl( p_cod_persona, imp.cod_persona )
   group by imp.nro_cuenta );

  If v_can_facturas is not null then
    v_nro_factura := fug_obt_lla_pardinamico('NRO_FACTURA');
    v_tot_facturas := v_nro_factura + v_can_facturas ;
  --Se actualiza por el total de facturas
    prg_act_par_dinamico('NRO_FACTURA',null, null, null, null, v_tot_facturas);

    for i in tarjetas loop
      if nvl( v_old_nro_cuenta, 0 ) <> i.nro_cuenta or v_can_items >= v_lim_items then
        v_nro_factura := v_nro_factura + 1;
        v_can_items := 0;
      end if;
      v_can_items := v_can_items + 1;
      Update ge_impuestos
         set nro_factura = v_nro_factura,
             cod_modulo  = 5
       where rowid = i.rowid;
      v_old_nro_cuenta := i.nro_cuenta;
    end loop;
  End if;
end PRT_OBT_NRO_FACTURA;
/

