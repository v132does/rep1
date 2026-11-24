create or replace function it.fug_obt_sig_sec_base(p_nom_secuencia in varchar2) return number is
   --COREPESI-1 / Proyecto Mejoras Performance SIPAP--
   v_numero number;
begin
   if p_nom_secuencia = 'S_SIG_HOR_USUARIO1' then
      select S_SIG_HOR_USUARIO1.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO2' then
      select S_SIG_HOR_USUARIO2.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO3' then
      select S_SIG_HOR_USUARIO3.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO4' then
      select S_SIG_HOR_USUARIO4.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO5' then
      select S_SIG_HOR_USUARIO5.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO6' then
      select S_SIG_HOR_USUARIO6.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO7' then
      select S_SIG_HOR_USUARIO7.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO8' then
      select S_SIG_HOR_USUARIO8.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO9' then
      select S_SIG_HOR_USUARIO9.Nextval into v_numero from dual;
   elsif p_nom_secuencia = 'S_SIG_HOR_USUARIO10' then
      select S_SIG_HOR_USUARIO10.Nextval into v_numero from dual;
   end if;
   return v_numero;
end;
/

