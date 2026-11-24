CREATE OR REPLACE TRIGGER IT.TB_PR_LIN_TIP_GAR_MAD
before insert or update or delete on PR_LIN_TIP_GAR_MAD
  for each row
declare
  -- local variables here
  v_estado pr_lineas.estado%type;
begin
   if updating then
      BEGIN
        select estado
          into v_estado 
          from pr_lineas
         where nro_linea = :new.nro_linea;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR(-20000, 'Error al obtener el Estado del Límite Nro. '||:new.nro_linea||'. '||sqlerrm );
      END;
      if nvl(v_estado, 'X') = 'A' then
        if :new.cod_modulo <> :old.cod_modulo or
           :new.cod_modalidad <> :old.cod_modalidad or
           :new.mto_limite <> :old.mto_limite then
           RAISE_APPLICATION_ERROR(-20000, 'No se puede modidificar el tipo de producto, si el Límite está aprobado.');
        end if;
      end if;
   end if;
end TB_PR_LIN_TIP_GAR_MAD;
/

