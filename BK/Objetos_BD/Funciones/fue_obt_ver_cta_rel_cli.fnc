create or replace function it.fue_obt_ver_cta_rel_cli
( P_COD_USUARIO IN BA_USUARIOS.COD_USUARIO%TYPE,
  P_COD_PERSONA IN BA_USUARIOS.COD_PERSONA%TYPE,
  P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE) return varchar2 is
  ----------------------------------
  -- DYDMR-5530 MAYO/2017 NAF
  -- Esta Funcion retorna S o N, segun el usuario pueda o no
  -- ver las cuentas relacionadas a funcionarios
  ----------------------------------
  v_tie_rel_cta_empleado varchar2(1);
  v_ver_cta              varchar2(1) := 'N';
  v_cod_per_usuario      ba_usuarios.cod_persona%type;          
begin   

  -- verifica si el usuario puede ver ctas de funcionarios
  Select nvl(t.ver_cta_empleados,'N'), t.cod_persona
     into v_ver_cta, v_cod_per_usuario
  from ba_usuarios t
  where cod_usuario = p_cod_usuario;
  
  if v_ver_cta = 'N' then
    v_tie_rel_cta_empleado := fug_es_empleado(p_cod_persona);
    -- verifica si la cuenta esta relacionada a un funcionario
    if nvl(v_tie_rel_cta_empleado,'N') = 'N' then
       select decode(nvl(count(*),0),0,'N','S')
        into v_tie_rel_cta_empleado
        from ge_cta_clientes x
       where x.cod_persona = p_cod_persona
         and exists (select 1 
                       from ge_cta_clientes y
                      where y.nro_cuenta = p_nro_cuenta
                        and y.relacion = 'P'
                        and fug_es_empleado(y.cod_persona) = 'S'
                        and y.nro_cuenta = x.nro_cuenta
                        and y.cod_persona <> x.cod_persona);
    end if;
    
    if v_tie_rel_cta_empleado = 'S' then
       if v_ver_cta = 'N' then
          -- Si codigo de persona que desea ver es su propio codigo si puede ver
          if v_cod_per_usuario = p_cod_persona then
             v_ver_cta := 'S';
          end if;
       end if;
    else
       v_ver_cta := 'S';
    end if;
  end if;
  
  return v_ver_cta;
exception 
  when others then
       raise_application_error(-20000, 'Error en fue_obt_ver_cta_rel_cli: ' || sqlerrm);
end;
/

