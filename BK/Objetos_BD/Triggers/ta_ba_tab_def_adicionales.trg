CREATE OR REPLACE TRIGGER IT.TA_BA_TAB_DEF_ADICIONALES
   After Delete Or Insert Or Update On ba_tab_def_adicionales
   For Each Row
Begin
   If deleting Then
      Delete From ba_tab_dat_adicionales a
       Where a.tab_relacion = :old.tab_relacion
         And a.parametro = :old.parametro;
   End If;
Exception
   When Others Then
      If Sqlcode <= -20000 Then
         Raise;
      Else
         raise_application_error(-20000, 'Al eliminar datos adicionales ' || Sqlerrm);
      End If;
End;
/

