CREATE OR REPLACE TRIGGER IT.TA_GE_FIR_SOLICITUDES
  after update
  on "IT"."GE_FIR_SOLICITUDES"
  for each row
begin
  if :new.estado = 'F' then
      update ge_fir_documentos c
         set c.estado = 'F'
       where c.cod_documento = :new.cod_documento
         and not exists(select 1 from ge_fir_circuitos d
                        where d.tip_documento = c.tip_documento
                          and d.nro_secuencia = :new.nro_secuencia + 1);
  end if;
end;
/

