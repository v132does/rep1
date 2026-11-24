CREATE OR REPLACE TRIGGER IT.TA_GE_FIR_DOCUMENTOS
  after insert or update
  on "IT"."GE_FIR_DOCUMENTOS"
  for each row
begin
  if inserting then
     pag_fir.pr_dis_documento(:new.cod_documento,:new.tip_documento,0,:new.cod_persona);
  elsif updating then
     if nvl(:old.nro_sec_firmada,0) <> :new.nro_sec_firmada then
        pag_fir.pr_dis_documento(:new.cod_documento,:new.tip_documento,:new.nro_sec_firmada,:new.cod_persona);
     end if;
  end if;
end;
/

