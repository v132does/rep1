CREATE OR REPLACE PROCEDURE IT.prg_obt_tot_operaciones(p_cod_persona in varchar2,
                                                    p_cod_modulo in varchar2,
                                                    p_cod_modalidad in varchar2,
                                                    p_total out number,
                                                    p_fecha in date,
                                                    p_resultado out varchar2,
                                                    p_hor_actual varchar2,
                                                    p_documento number) is
-- proceso con el que se obtiene el total de operaciones del dia para un
-- cliente determinado por modulo y modalidad
-- en caso de que el monto total de las operaciones superen el monto del parámetro
-- OPE_SUP_MON_FUERTE(10000 USD) se llama al proceso para imprimir la declaración

v_mto_sup          number := fug_obt_pardinamico('OPE_SUP_MON_FUERTE');
v_mto_detalle      number(18,2);
cursor c_movimientos is
 select  m.cod_moneda, m.monto, m.cotizacion
      from ge_movimientos m, ge_cta_clientes c
      where c.relacion = 'P'
         and m.nro_cuenta = c.nro_cuenta
         and m.nro_caja is not null
         and m.reversado = 'N'
         and m.cod_mod_padre <> 7
         and c.cod_persona = p_cod_persona
         and nvl(m.protegido,'N') = 'N'
         and fecha = p_fecha
         and not exists (select 1
                        from ah_cta_certificados
                        where nro_cuenta = m.nro_cuenta
                        and nro_cta_renovada is not null)
         -- No incluir CDA renovados
         and m.monto > 0
         and m.cod_modulo in (3,4)
         and m.cod_tra_padre in (136,351,352)
         --and pag_gen.fu_con_mon_a_moneda(m.cod_moneda,'USD', m.monto, m.cotizacion) <= fug_obt_pardinamico('OPE_SUP_MON_FUERTE')
         and m.estado <> 'J';--JCLG

   v_nombre           ba_personas.nom_completo%type;
   v_nro_documento    ba_personas.nro_documento%type;
   v_tip_persona      ba_personas.tipo%type;
   v_nacionalidad     ba_paises.nacionalidad%type;
   v_direccion        ba_direcciones.direccion%type;
   v_ciudad           ba_ciudades.descripcion%type;
   v_cod_modulo       ge_modalidades.cod_modulo%type := p_cod_modulo;
   v_cod_modalidad    ge_modalidades.cod_modalidad%type := p_cod_modalidad;
   v_nro_cuenta       ge_cuentas.nro_cuenta%type;
   v_fecha            ge_movimientos.fecha%type;
   v_resultado        varchar2(4000);
   v_total1           number(18,2);
   v_total2           number(18,2);

begin
   begin
      select sum(decode(o.cod_moneda,'USD',o.monto,
               pag_gen.FU_CON_MON_A_MONEDA(o.cod_moneda,
               'USD',
               o.monto,
               o.cotizacion))) monto
      into v_total1
      from (select monto, fecha, hora, cod_usuario, cod_moneda, cotizacion
            from ge_movimientos
            where nro_secuencia = 1
            and nvl(protegido,'N') = 'N'
            and pag_gen.fu_con_mon_a_moneda(cod_moneda,'USD', monto, cotizacion) <= v_mto_sup
            ) o,
            ge_movimientos g
      where g.cod_modulo = 7
         and g.cod_transaccion = 760
         and g.reversado = 'N'
         and nvl(protegido,'N') = 'N'
         and nro_documento2 = p_cod_persona
         and g.fecha = o.fecha
         and g.hora = o.hora
         and g.fecha = p_fecha
         and g.cod_usuario = o.cod_usuario
         and g.cod_modulo = 7 --p_cod_modulo
         and g.nro_documento2 is not null
         and g.estado <> 'J'--JCLG
      group by g.nro_documento2;
   exception
      when no_data_found then
          v_total1 := 0;
      when others then
          v_total1 := 0;
   end;

   v_total2 := 0;
   for det in c_movimientos loop
       select decode(det.cod_moneda,'USD',det.monto,
              pag_gen.FU_CON_MON_A_MONEDA(det.cod_moneda,
              'USD',
              det.monto,
              det.cotizacion))
          into v_mto_detalle from dual;
       if v_mto_detalle <= v_mto_sup then
          v_total2 := nvl(v_total2,0) + nvl(v_mto_detalle,0);
       end if;
   end loop;
   begin
      select  sum(decode(m.cod_moneda,'USD',m.monto,
               pag_gen.FU_CON_MON_A_MONEDA(m.cod_moneda,
               'USD',
               m.monto,
               m.cotizacion))) monto
      into v_total2
      from ge_movimientos m ,
            ge_cta_clientes c,
            ge_transacciones t
      where c.relacion = 'P'
         and m.nro_cuenta = c.nro_cuenta
         and m.cod_transaccion = t.cod_transaccion
         and m.cod_modalidad = t.cod_modalidad
         and m.cod_modulo = t.cod_modulo
         and m.nro_caja is not null
         and m.reversado = 'N'
         and m.cod_mod_padre <> 7
         and c.cod_persona = p_cod_persona
         and nvl(m.protegido,'N') = 'N'
         and fecha = p_fecha
         and not exists (select 1
                        from ah_cta_certificados
                        where nro_cuenta = m.nro_cuenta
                        and nro_cta_renovada is not null)
         -- No incluir CDA renovados
         and m.monto > 0
         and m.cod_modulo in (3,4)
         and m.cod_tra_padre in (136,351,352)
         and pag_gen.fu_con_mon_a_moneda(m.cod_moneda,'USD', m.monto, m.cotizacion) <= fug_obt_pardinamico('OPE_SUP_MON_FUERTE')
         and m.estado <> 'J'--JCLG
      group by c.cod_persona;
   exception
      when no_data_found then
          v_total2 := 0;
      when others then
          v_total2 := 0;
   end;
   p_total := nvl(v_total1,0) + nvl(v_total2,0);
   if p_total >= v_mto_sup then
      begin
         select b.nom_completo, b.nro_documento, b.tipo, p.nacionalidad, d.direccion, c.descripcion
         into V_NOMBRE, V_NRO_DOCUMENTO, V_TIP_PERSONA, V_NACIONALIDAD, V_DIRECCION, V_CIUDAD
         from ba_personas b, ba_direcciones d, ba_ciudades c, ba_paises p
         where b.cod_pais = p.cod_pais
         and d.cod_ciudad = c.cod_ciudad
         and d.cod_pais = c.cod_pais
         and d.principal = 'S'
         and b.cod_persona = d.cod_persona
         and b.cod_persona = p_cod_persona;
      exception
         when no_data_found then
            v_nombre := null;
            v_nro_documento := null;
            v_tip_persona := null;
            v_nacionalidad := null;
            v_direccion := null;
            v_ciudad := null;
      end;

      begin
         prg_ver_mov_superiores(P_COD_PERSONA, P_COD_MODULO, P_COD_MODALIDAD,V_NOMBRE,
                              V_NRO_DOCUMENTO,V_TIP_PERSONA,V_NACIONALIDAD,V_DIRECCION,
                              V_CIUDAD,P_FECHA, V_NRO_CUENTA, v_RESULTADO);
         p_resultado := v_resultado;
         insert into ge_dec_juradas (fecha,hora,cod_mod_padre,cod_persona,nro_documento,monto,impresion)
         values (p_fecha,p_hor_actual,p_cod_modulo,p_cod_persona,p_documento,p_total,v_resultado);
      end;
   end if;
   p_total :=  0;
exception
  when no_data_found then
   p_total :=  0;
end;
/

