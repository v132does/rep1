create or replace procedure it.prs_tra_obt_usu_hor_mov_pym(p_usuario in varchar2,
                                                           p_usu_mov out varchar2,
                                                           p_hor_mov out varchar2) is

  v_nro_sec  number;
  v_can_user number;
  v_nro_user number;

  v_nro_hor     number;
  v_ind_usuario number;
begin
  --TTCE-101
  select count(*)
    into v_can_user
    from ba_cod_referencias
   where dominio = 'USU_MOV_SERVICIO'
     and abreviatura = p_usuario;

  v_nro_sec  := fue_obt_sig_secuencia('S_SER_PAYMPV');
  v_nro_user := mod(v_nro_sec, v_can_user);
  p_usu_mov  := it.FUE_OBT_VAL_USER_DOMINIO('USU_MOV_SERVICIO',
                                            v_nro_user,
                                            p_usuario);

  if instr(p_usu_mov, '_', 1) = 0 then
    v_ind_usuario := 0;
  else
    v_ind_usuario := substr(p_usuario, instr(p_usu_mov, '_', 1) + 1, 2);
  end if;

  if v_ind_usuario > 0 then
    v_nro_sec := fue_obt_sig_secuencia('s_hor_movpaympv' /*||'_'*/
                                       || v_ind_usuario);
  elsif v_ind_usuario = 0 then
    v_nro_sec := fue_obt_sig_secuencia('S_HOR_MOVPAYMPV');
  end if;

  v_nro_hor := mod(v_nro_sec, 86400);

  p_hor_mov := TO_CHAR(trunc(v_nro_hor / 3600), 'FM9900') || ':' ||
               TO_CHAR(TRUNC(MOD(v_nro_hor, 3600) / 60), 'FM00') || ':' ||
               TO_CHAR(MOD(v_nro_hor, 60), 'FM00');

exception
  when others then
    p_usu_mov := p_usuario;
    p_hor_mov := to_char(sysdate, 'HH24:MI:SS');
end;
/
