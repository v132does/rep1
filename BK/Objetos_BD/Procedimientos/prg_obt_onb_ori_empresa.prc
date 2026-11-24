create or replace procedure it.prg_obt_onb_ori_empresa(p_key       in varchar2,
                                                            p_origen    out varchar2,
                                                            p_cod_error out number,
                                                            p_mensaje   out varchar2) is
  v_origen    varchar2(100);
  v_det_error varchar2(4000);

begin

  if p_key is null then
    p_cod_error := 1;
    p_mensaje   := 'El key no puede ser nulo';
    return;
  end if;

  begin
    select t.origen
      into v_origen
      from ge_onb_emp_origen t
     where t.key = p_key;
  exception
    when no_data_found then
      p_origen    := 'NO IDENTIFICADO';
      p_cod_error := 0;
      p_mensaje   := 'El Key ingresado no existe.';
    when others then
      p_origen    := 'NO IDENTIFICADO';
      v_det_error := substr('Ocurrió un error durante la consulta' ||
                            sqlerrm,
                            1,
                            4000);
      p_cod_error := 2;
      p_mensaje   := 'Ocurrió un error durante la consulta';
  end;

  if nvl(p_cod_error, 0) != 0 then
    p_cod_error := p_cod_error;
    p_mensaje   := p_mensaje;
  else
    p_cod_error := 0;
    p_mensaje   := nvl(null,p_mensaje);
    p_origen    := nvl(v_origen,p_origen);
  end if;

exception
  when others then
    p_origen    := 'No identificado';
    p_cod_error := 999;
    p_mensaje   := 'Ocurrió un error inesperado';
    v_det_error := substr('Ocurrió un error inesperado' || sqlerrm, 1, 4000);
end;
/

