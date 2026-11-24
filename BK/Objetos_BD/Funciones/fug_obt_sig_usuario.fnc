create or replace function it.fug_obt_sig_usuario(p_cod_usuario in varchar2) return varchar2 is

--COREPESI-1 / Proyecto Mejoras Performance SIPAP--
v_cod_usu_retornar varchar2(10);
v_cod_usu_actual varchar2(10);
v_cod_usu_nuevo varchar2(10);
v_can_usu_habilitados number;
v_can_usu_utilizados number;
v_ord_usuario varchar2(10);
v_orden number;
v_seguir varchar2(1) := 'N';
v_usu_agotado varchar2(1) := 'N';
v_cod_usu_pivot varchar2(10);
v_len_usu_pivot number;

begin
  v_cod_usu_pivot := p_cod_usuario;
  v_len_usu_pivot := length(v_cod_usu_pivot);

  select X2.COD_USU_ACTUAL, X2.CAN_USU_HABILITADOS, X2.CAN_USU_UTILIZADOS
    into v_cod_usu_actual, v_can_usu_habilitados, v_can_usu_utilizados
    from ge_CON_par_usuarios x2
   where x2.cod_usu_pivot = v_cod_usu_pivot;

  loop
      v_cod_usu_nuevo := v_cod_usu_pivot;
      v_ord_usuario := nvl(substr(v_cod_usu_actual,nvl(v_len_usu_pivot,0)+1),'X');
      if fug_val_es_numerico(v_ord_usuario) = 'S' then
         v_orden := to_number(v_ord_usuario) + 1;
         if v_orden > v_can_usu_habilitados then
            v_orden := null;
         end if;
      else
        v_orden := 1;
      end if;
      if v_orden > (v_can_usu_habilitados - 1) then
         v_cod_usu_retornar := v_cod_usu_nuevo;
      else
         v_cod_usu_retornar := v_cod_usu_nuevo||trim(to_char(v_orden));
      end if;
      --Verificar si ya esta utilizado--
      if v_can_usu_utilizados >= v_can_usu_habilitados then
         v_seguir := 'N';
         v_usu_agotado := 'S';
      else
         v_seguir := 'N';
      end if;
      exit when v_seguir = 'N';
  end loop;
  if v_usu_agotado = 'S' then
     v_cod_usu_retornar := null;
  end if;
  return v_cod_usu_retornar;
end;
/

