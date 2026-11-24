create or replace procedure it.prg_act_con_celular(p_cod_persona in varchar2, p_respuesta in varchar2) is
  v_existe       varchar2(1);
  v_nro_celular  ba_telefonos.telefono%type;
  v_fecha        ba_act_dat_clientes.fec_confirmacion%type := sysdate;
  procedure lp_obt_celular(p_cod_persona varchar2) is
    begin
      select 'S', a.tel_area||a.tel_numero
        into v_existe, v_nro_celular
        from ba_act_dat_clientes a
       where a.estado = 'R'
         and a.tel_tip_linea = 'C'
         and a.tip_solicitud = 'C'
         and a.cod_persona = p_cod_persona
         and a.fec_confirmacion = (select max(b.fec_confirmacion) 
                                     from ba_act_dat_clientes b
                                    where a.cod_persona = b.cod_persona
                                      and b.estado = 'R'
                                      and b.tel_tip_linea = 'C'
                                      and b.tip_solicitud = 'C');
    exception
      when no_data_found then
        v_existe := 'N';
      when too_many_rows then
        v_existe := 'S';
      when others then
        v_existe := 'N';
    end;
begin
  if p_respuesta = '#AS#' then
     lp_obt_celular(p_cod_persona);
     if v_existe = 'S' then
        prg_act_dat_atm(p_cod_persona, v_nro_celular);
        update ba_act_dat_clientes a
           set a.estado = 'C',
               a.fec_confirmacion = v_fecha
         where a.estado = 'R'
           and a.tel_tip_linea = 'C'
           and a.tip_solicitud = 'C'
           and a.cod_persona = p_cod_persona
           and a.fec_confirmacion = (select max(b.fec_confirmacion) 
                                     from ba_act_dat_clientes b
                                    where a.cod_persona = b.cod_persona
                                      and b.estado = 'R'
                                      and b.tel_tip_linea = 'C'
                                      and b.tip_solicitud = 'C');
     end if;
  end if;
end prg_act_con_celular;
/

