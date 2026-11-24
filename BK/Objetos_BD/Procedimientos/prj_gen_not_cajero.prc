create or replace procedure it.prj_gen_not_cajero(p_nro_caja in number, p_mensaje in varchar2, p_detalle in varchar2)
is
 v_cod_persona   ba_personas.cod_persona%type;
 v_nro_secuencia cr_per_notas.nro_secuencia%type;
begin
  select cod_persona
    into v_cod_persona
    from ba_usuarios
   where cod_usuario = (select nvl(cod_usuario,cod_usu_responsable)
                          from cj_cajas
                         where nro_caja = p_nro_caja);
  if v_cod_persona is not null then
     select nvl(max(nro_secuencia),0) 
       into v_nro_secuencia
       from cr_per_notas 
      where cod_persona = v_cod_persona;                        
     
     insert into cr_per_notas (cod_persona, nro_secuencia, tipo, fecha, descripcion, detalle, automatico, estado, medio)
     values (v_cod_persona, v_nro_secuencia + 1, 'A', pag_cal.FU_OBT_FEC_ACTUAL(9), p_mensaje, p_detalle, 'N', 'P', 'C');
  end if;     
end;
/

