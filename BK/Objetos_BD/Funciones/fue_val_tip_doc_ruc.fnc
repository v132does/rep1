create or replace function it.fue_val_tip_doc_ruc(p_nro_documento in varchar2)
  return varchar2 is
  v_msj_error varchar2(300);
  v_ruc       varchar2(10);
  v_dv        varchar2(1);

begin
  begin
    if length(p_nro_documento) - length(replace(p_nro_documento, '-', '')) <> 1 then
      v_msj_error := 'El RUC debe contener el digito verificador separado por un - (guion)';
    elsif instr(p_nro_documento,'-') <> (length(p_nro_documento) - 1) then
      v_msj_error := 'Posicion del -(guion) incorrecta en el RUC';
    elsif fue_val_es_numerico(replace(p_nro_documento, '-', '')) = 'N' then
      v_msj_error := 'El RUC no puede contener valores no numericos';
    else
      v_ruc := substr(p_nro_documento, 1, instr(p_nro_documento, '-') - 1);
      v_dv  := substr(p_nro_documento, instr(p_nro_documento, '-') + 1, 1);
      if v_dv <> fue_obt_ruc_dig_verificador(v_ruc) then
        v_msj_error := 'El digito verificador del RUC no es válido';
      end if;
    end if;
  exception
    when others then
      v_msj_error := 'Error en formato del RUC. ' || substr(sqlerrm, 1, 290);
  end;
  return v_msj_error;
end;
/

