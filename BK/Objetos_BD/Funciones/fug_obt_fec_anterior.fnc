create or replace function it.FUG_OBT_FEC_ANTERIOR(p_cod_modulo in number)
                            return DATE  is
V_FEC_anterior GE_CALENDARIOS.FEC_ANTERIOR%TYPE;
Begin
   --Obtiene la fecha anterior del módulo
   select fec_anterior
     into v_fec_anterior
     from ge_calendarios
    where cod_modulo = p_cod_modulo;
return v_fec_anterior;
exception
    when no_data_found then
       raise_application_error(-20000,
       'No existe fecha anterior. p/'||to_char(p_cod_modulo) ||' - ' ||sqlerrm);

end ;
/

