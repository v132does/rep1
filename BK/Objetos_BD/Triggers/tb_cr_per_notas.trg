CREATE OR REPLACE TRIGGER IT.TB_CR_PER_NOTAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CR_PER_NOTAS
 FOR EACH ROW


DECLARE

  v_secuenc cr_per_notas.nro_secuencia%type;
begin
   if inserting then
     If :new.nro_secuencia is null Then
        Select s_nro_secuencia.nextval
        into v_secuenc
        from dual;
        :new.nro_secuencia := v_secuenc;
     end if;
  End If;
end;
/

