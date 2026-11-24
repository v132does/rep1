CREATE OR REPLACE TRIGGER IT.ta_sb_gru_eco_bcp_det
  after insert on sb_gru_eco_bcp_det  
  for each row
DECLARE
   -- local variables here
BEGIN
   INSERT INTO ba_cod_referencias
      (dominio, significado, abreviatura, val_minimo)
   VALUES
      ('GRU_ECO_BCP', :new.grupo, :new.grupo, :new.numero);
   -- VAL_MAXIMO queda a cargo del usuario para su macheo con los grupos económicos definidos en ITGF
EXCEPTION
   WHEN dup_val_on_index THEN
      --PK_BA_COD_REFERENCIAS: DOMINIO, VAL_MINIMO ya existe
      NULL;
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Al Ins.Dominio GRU_ECO_BCP:' || SQLERRM);
END ta_sb_gru_eco_bcp_det;
/

