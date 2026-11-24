create or replace function it.FUG_VAL_CTA_TRANSFERENCIAS (
       p_nro_cuenta      ge_cuentas.nro_cuenta%type,
       p_cod_transaccion ge_transacciones.cod_transaccion%type)
return boolean
is
   v_permiso           boolean := false;
   v_cod_persona       ba_personas.cod_persona%type;
   v_cod_modulo        ba_modulos.cod_modulo%type;
   v_cod_modalidad     ge_modalidades.cod_modalidad%type;
   v_cod_moneda        ba_monedas.cod_moneda%type;
   v_cod_oficina       ba_oficinas.cod_oficina%type;
   v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
   v_cod_rol           ge_par_dinamicos.val_parametro/*ba_roles.cod_rol*/%type := null;--dydmr-7403
   v_tie_permiso       varchar2(1);
begin
   begin
      select a.cod_persona, a.cod_modulo, a.cod_modalidad, a.cod_oficina, b.cod_moneda, b.cod_sub_modalidad
      into   v_cod_persona, v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_cod_sub_modalidad
      from   ge_cta_clientes a, ge_cuentas b
      where  a.nro_cuenta = b.nro_cuenta
      and    a.nro_cuenta = p_nro_cuenta
      and    relacion = 'P';
   exception
      when no_data_found then
         raise_application_error(-20000,'Error:Cta.'||p_nro_cuenta||' no existe.');
      when others then
         raise_application_error(-20000,'Error:'||sqlerrm);
   end;

   if v_cod_persona = fug_obt_per_entidad then
      v_cod_rol := fug_obt_pardinamico('ROL_CTA_TRANSFERENCIAS',
                                        v_cod_modulo,
                                        v_cod_modalidad,
                                        v_cod_moneda,
                                        v_cod_oficina,
                                        v_cod_sub_modalidad);
      if v_cod_rol is null then
         v_permiso := false;
      else
         --v_tie_permiso := FUG_VER_USU_PERMISO(user,v_cod_modulo,v_cod_modalidad,p_cod_transaccion);
         begin
           Select 'S' into v_tie_permiso
             from ba_usu_roles a,ge_tra_roles b
            where a.cod_rol = b.cod_rol
              and a.cod_usuario = user
              and b.cod_transaccion = p_cod_transaccion
              and b.cod_modulo = v_cod_modulo
              and b.cod_modalidad = v_cod_modalidad
              and instr(v_cod_rol,','||a.cod_rol||',') > 0;--dydmr-7403
         exception
           when no_data_found then
             v_tie_permiso := 'N';
           when too_many_rows then
             v_tie_permiso := 'S';
           when others then
             v_tie_permiso := 'N';
         end;
         if nvl(v_tie_permiso,'N') = 'S' then
            v_permiso := true;
         else
            v_permiso := false;
         end if;
      end if;
   else
      v_permiso := true;
   end if;
   return v_permiso;
end;
/

