create or replace function it.fue_obt_Titulo(p_palabra varchar2)
 return varchar2 is
  v_palabra       varchar2(2000);
  v_longitud      number;
  v_inicial       number;
  v_final         number;
  v_pinicial      number;
  v_pfinal        number;
  v_einicial      number;
  v_efinal        number;
  v_letras        varchar2(20);
begin
   -- Hace el InitCap para iniciar...
   v_palabra := InitCap(p_palabra);
   -- Reemplaza los casos mas necesarios  p/, c/, s/, 's --
   v_palabra := replace(v_palabra, 'P/', 'p/');
   v_palabra := replace(v_palabra, 'C/', 'c/');
   v_palabra := replace(v_palabra, 'S/', 's/');
   v_palabra := replace(v_palabra, chr(39)||'S', chr(39)||'s');
   --
   v_inicial         := 1;
   v_final           := 1;
   v_longitud        := NVL(length(v_palabra), 0);
   Loop
      If v_Inicial = 0 or v_inicial >= v_Longitud Then
         Exit;
      End If;
      If v_final - v_inicial between 1 and 5 Then
         v_Letras := substr(v_palabra, v_inicial, v_final-v_inicial+1);
         If lower(LTRIM(RTRIM(v_Letras))) in 
               ('srl', 'sa', 'sacic', 'saeca', 'saci', 'eca') Then
            -- Le pone las letras en mayusculas 
            v_palabra := substr(v_palabra, 1, v_inicial-1)||
                         upper(v_Letras)||
                         substr(v_palabra, v_final+1, v_Longitud);
         Elsif lower(LTRIM(RTRIM(v_Letras))) in 
               ('del','a','de','la','el','en','por',
                'para','y','e','con','entre','los','las','contra','sin') Then
            -- Le pone las letras en minusculas
            v_palabra := substr(v_palabra, 1, v_inicial-1)||
                         lower(v_Letras)||
                         substr(v_palabra, v_final+1, v_Longitud);
         End If;
      End If;
      --- Inicial ---
      v_pinicial := instr(v_palabra, '.', v_final);
      v_einicial := instr(v_palabra, ' ', v_final);
      If v_pinicial != 0 and v_einicial != 0 Then
         v_inicial := Least(v_pinicial, v_einicial);
      Else
         v_inicial := Greatest(v_pinicial, v_einicial);
      End If;
      --- Final ---
      If v_inicial != 0 Then
         v_pfinal := instr(v_palabra, '.', v_inicial + 1);
         v_efinal := instr(v_palabra, ' ', v_inicial + 1);
         If v_pfinal != 0 and v_efinal != 0 Then
            v_final := Least(v_pfinal, v_efinal);
         Else
            v_final := Greatest(v_pfinal, v_efinal);
         End If;
      Else
         v_final := 0;
      End If;
      If v_final = 0 Then
         v_final := v_Longitud;
      End If;
      If v_inicial != 0 Then
         v_inicial := v_inicial + 1;
      End If;
   End Loop;
  -- Retorna la Palabra modificada...
  Return v_palabra;

end;
/

