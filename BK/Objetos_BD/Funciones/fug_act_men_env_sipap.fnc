create or replace function it.fug_act_men_env_sipap(p_referencias IN typ_referencias,
                                                    p_estado      IN ge_men_env_sipap.estado%TYPE)
  return typ_mensajerespuesta is
  v_retorno typ_mensajeRespuesta := typ_mensajeRespuesta;
  v_existe  varchar2(1) := 'N';
  i NUMBER;
begin
  paw_uti.pr_mensajeusuario(paw_uti.msg_ok,
                            v_retorno.nombrerespuesta,
                            v_retorno.descripcionrespuesta,
                            v_retorno.error);
  i := p_referencias.FIRST;
IF i IS NULL THEN

       v_retorno.nombreRespuesta:=1;
      v_retorno.nombreRespuesta:='SIN_REG';
      v_retorno.descripcionRespuesta:='Error ,sin registros';
      v_retorno.error:='S';
ELSE
  FOR i IN p_referencias.first .. p_referencias.last LOOP
    begin
      Select 'S'
        into v_existe
        from ge_men_env_sipap a
       where a.id_mensaje = p_referencias(i).id_mensaje
       and a.nro_referencia=p_referencias(i).nro_referencia
       and a.estado='PENDING';
    exception
      when too_many_rows then
        v_existe := 'S';
      when no_data_found then
        v_existe := 'N';
      when others then
        v_existe := 'N';
    end;
    if v_existe = 'S' then
       update ge_men_env_sipap
          set estado = p_estado
        where id_mensaje = p_referencias(i).id_mensaje;
    else
      v_retorno.nombreRespuesta:=2;
      v_retorno.nombreRespuesta:='NO_EXISTE';
      v_retorno.descripcionRespuesta:='Error ,uno o varias referencias no existe';
      v_retorno.error:='S';
    end if;
    
  END LOOP;
END IF; 
  RETURN v_retorno;

end;
/
