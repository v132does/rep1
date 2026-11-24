create or replace procedure it.prm_ver_ge_clientes
(p_cod_persona in ba_personas.cod_persona%type,
 p_cod_oficina in ba_oficinas.cod_oficina%type,
 p_nro_oficial in number) is
   v_existe      varchar2(01) := 'N';
   v_cod_oficial ba_usuarios.cod_usuario%type;
   v_nro_oficial number(3);
begin
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   --- Verifica si existe el cliente
   v_existe := 'N';
   begin
      select 'S' into v_existe
        from ge_clientes
       where cod_persona = p_cod_persona;
   exception
      when no_data_found then v_existe := 'N';
      when others then v_existe := 'N';
   end;
   if p_nro_oficial is not null then
      v_nro_oficial := p_nro_oficial;
   else
      v_nro_oficial := (p_cod_oficina + 100);
   end if;
   begin
      select o.cod_operador into v_cod_oficial
        from agente_operador o
       where o.cod_agente = v_nro_oficial;
   exception
      when no_data_found then
           raise_application_error(-20000,'Agente operador no registrado p/'||v_nro_oficial);
   end;
   if v_existe = 'N' then
      insert into ge_clientes
      (cod_persona, cod_oficina, exo_impuestos, cod_usu_oficial,
       cli_especial, residente, cod_sec_contable, cod_tip_deudor, cod_seg_cliente)
      values (p_cod_persona, p_cod_oficina, 'N', v_cod_oficial,
       'N', 'S', 'N', 2, 34) ;
   end if;
   commit;
end prm_ver_ge_clientes;
/

