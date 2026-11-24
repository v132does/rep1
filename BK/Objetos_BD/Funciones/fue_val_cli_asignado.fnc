create or replace function it.FUE_VAL_CLI_ASIGNADO(p_cod_usu_oficial in ge_clientes.cod_usu_oficial%type,
                                                p_cod_cliente     in ge_clientes.cod_persona%type)
  return varchar2 is
  v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;
  v_resultado       varchar2(1);
  v_cod_area        ba_usuarios.cod_area%type;
  v_cod_are_usuario ba_usuarios.cod_area%type;
  v_val_parametro   ge_par_dinamicos.val_parametro%type;
  v_sig_posicion    number := 1;
  v_pos_coma        number;
begin
   /**Se obtiene el Código del Oficial de Cuentas (Gestor).**/
   begin
      select cod_usu_oficial
        into v_cod_usu_oficial
        from ge_clientes
       where cod_persona = p_cod_cliente;
   exception
      when no_data_found then
         raise_application_error(-20000,'Oficial de Cuentas del cliente :'||p_cod_cliente||' no se encuentra registrado en el sistema.');
      when others then
         raise_application_error(-20001, 'Error al buscar en GE_CLIENTES :  ' || sqlerrm);
   end;
   /**Se verifica si el Cliente está asignado a ese Gestor.**/
   if v_cod_usu_oficial = p_cod_usu_oficial then
      v_resultado := 'S';
   else
      /**Se verifica si el Cliente está asignado a un Gestor que es supervisado por el usuario 
         pasado como parámetro.**/
      if FUE_OBT_SUP_USUARIO(v_cod_usu_oficial) = p_cod_usu_oficial then
         v_resultado := 'S';
      else
         /**Se verifica si el código del área del usuario se encuentra dentro de los valores seteados 
            en el nuevo parámetro dinámico TAS_PER_ARE_CONTROL.**/
         v_val_parametro := FUG_OBT_PARDINAMICO('TAS_PER_ARE_CONTROL',null,null,null,FUG_OBT_OFI_USUARIO(p_cod_usu_oficial),null);
         IF v_val_parametro IS NULL THEN
            v_resultado := 'N';
         else
            v_cod_are_usuario  := FUE_OBT_ARE_USUARIO(p_cod_usu_oficial);
            begin
               for i in 1 .. (length(v_val_parametro) - length(replace(v_val_parametro, ','))) + 1 loop
                  v_pos_coma := instr(v_val_parametro, ',', v_sig_posicion);
                  if v_pos_coma <> 0 then
                     v_cod_area := trim(substr(v_val_parametro, v_sig_posicion, v_pos_coma - v_sig_posicion));
                     v_sig_posicion  := v_pos_coma + 1;
                  else
                     v_cod_area := trim(substr(v_val_parametro, v_sig_posicion));
                  end if;
                  exit when v_cod_area is null;
                  if v_cod_are_usuario = v_cod_area then
                     v_resultado := 'S';
                     exit;
                  else
                     v_resultado := 'N';  
                  end if;
               end loop;
            end;
         end if;
      end if;
   end if;
   return v_resultado;
end;
/

