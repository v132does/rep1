CREATE OR REPLACE Procedure IT.prg_ver_ano_mes(p_valor In Varchar2) Is
   v_fecha Date;
Begin
   If length(p_valor) != 6 Then
      raise_application_error(-20000, 'El formato debe ser AAAAMM (AñoMes).');
   End If;
   Begin
      v_fecha := to_date(p_valor || '01', 'YYYYMMDD');
   Exception
      When Others Then
         If Sqlcode = -1841 Then
            raise_application_error(-20003, 'Año no válido. ' || Sqlerrm);
         Elsif Sqlcode = -1843 Then
            raise_application_error(-20003, 'Mes no válido. ' || Sqlerrm);
         Else
            raise_application_error(-20002, 'El formato debe ser AAAAMM (AñoMes). ' || Sqlerrm);
         End If;
   End;
   begin
     select max(fecha)
       into v_fecha
       from cb_sal_consolidados_dia a
      where to_char(a.fecha,'YYYYMM') = p_valor;
   exception
     when others then
     v_fecha := null;
   end;
   if v_fecha is null then
     raise_application_error(-20002, 'Año Mes incorrecto para Saldos Consolidados Diario.');
   end if;
Exception
   When Others Then
      If Sqlcode <= -20000 Then
         Raise;
      Else
         raise_application_error(-20003, 'PRG_VER_ANO_MES. ' || Sqlcode);
      End If;
End;
/

