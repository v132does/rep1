create or replace function it.f_nom_mes(p_mes number) Return varchar2 is
   type meses is varray(12) of varchar2(20);
   v_meses meses := null;
   v_nombre varchar2(20);
Begin
  v_meses(1) := 'Enero';
  v_meses(2) := 'Febrero';
  v_meses(3) := 'Marzo';
  v_meses(3) := 'Marzo';
  v_meses(3) := 'Marzo';
  v_meses(4) := 'Marzo';
  v_meses(5) := 'Marzo';
  v_meses(6) := 'Marzo';
  v_meses(7) := 'Marzo';
  v_meses(8) := 'Marzo';
  v_meses(9) := 'Marzo';
  v_meses(10) := 'Marzo';
  v_meses(11) := 'Marzo';
  v_meses(12) := 'Marzo';

  v_nombre := v_meses(p_mes);
  Return (v_nombre);
  
End;
/

