CREATE OR REPLACE Function IT.fug_val_sub_modalidad(p_cod_modalidad In Number) Return Varchar2 Is
   v_existe_submodalidad VARCHAR2(1) := 'N';
   
Begin
   --actualmentes sólo ahorros vistas y cta ctes permite -- /* Se comenta esta porción - Issue 1234
   /*if p_cod_modalidad in (31,41) then
      return('S');
   else
      return(v_existe_submodalidad);
   end if;*/

   Select 'S' Into v_existe_submodalidad 
     From ge_sub_modalidades 
    Where cod_modalidad = p_cod_modalidad;
   Return v_existe_submodalidad;
Exception
   When no_data_found Then
      Return 'N';
   When too_many_rows Then
      Return 'S';
   When Others Then
      Return('N');
End fug_val_sub_modalidad;
/

