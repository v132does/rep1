create or replace function it.FUL_FOR_DAT_SWIFT(P_CADENA IN VARCHAR2, P_CAN_CARACTERES IN NUMBER) return varchar2 is
  v_longitud number(6);
  v_texto varchar2(1000) := null;
  v_salto varchar2(2) := CHR(10);
  v_ciclo number(4);
  v_indice number(4);
  v_pos_inicial number(4) := 1;
begin
  if p_cadena is null then
     raise_application_error(-20000,'La Cadena para Formatear no puede ser nula.');
  end if;
  if nvl(p_can_caracteres,0) = 0 then
     raise_application_error(-20000,'La Cantidad de Caracteres no puede ser (0).');
  end if;
  v_longitud := length(p_cadena);
  select trunc(v_longitud/p_can_caracteres)+(decode(mod(v_longitud,p_can_caracteres),0,0,1))
    into v_ciclo
    from dual;
  for v_indice in 1..v_ciclo loop
      v_texto := v_texto||substr(p_cadena,v_pos_inicial,p_can_caracteres);
      if v_longitud > p_can_caracteres*v_indice then
         v_texto := v_texto||v_salto;
      end if;
      v_pos_inicial := (p_can_caracteres*v_indice)+1;
  end loop;
  return(v_texto);
exception
  when others then
       raise_application_error(-20000,'Error en FUL_FOR_DAT_SWIFT: '||sqlerrm);
end FUL_FOR_DAT_SWIFT;
/

