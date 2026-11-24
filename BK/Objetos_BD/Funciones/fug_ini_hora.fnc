create or replace function it.fug_ini_hora
   (p_fecha in date default sysdate, p_formato in varchar2 default 'HH24:MI:SS')
 return varchar2  is
 /* funcion que devuelve la hora de inicio para cada proceso de cierre para evitar duplicacion de claves */
v_hora varchar2(8) := to_char(nvl(p_fecha,sysdate),nvl(p_formato,'HH24:MI:SS'));
v_max_hora varchar2(8);
begin
   /*select max(hora)
     into v_max_hora
     from ge_movimientos
    where cod_usuario = user;
  if v_max_hora >= v_hora then
     v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_max_hora);
  end if;
  if v_hora = '00:00:00' then
     select max(hora)
       into v_max_hora
       from ge_movimientos
      where cod_usuario = user
        and hora < '06:00:00';
    if v_max_hora >= v_hora then
       v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_max_hora);
    end if;
  end if;*/
  v_hora := fug_obt_hor_disponible(trunc(p_fecha),v_hora,user,'N');
  return v_hora;
exception
  when others then
      return v_hora;
end;
/

